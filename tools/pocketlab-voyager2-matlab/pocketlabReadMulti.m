function [t,data,info] = pocketlabReadMulti(sensorNames,recordTime,Fs,varargin)
%POCKETLABREADMULTI Simultaneous Voyager 2 sensor acquisition.
%
%   [t,data,info] = pocketlabReadMulti( ...
%       ["acceleration","gyroscope"],10,20)
%
%   Sensor types are enabled together via a combined configuration bitmask.
%   ONLY packets matching the ASSUMED format
%       six-byte header + [sensor1...sensorN float32 values] per sample
%   are tentatively decoded. Other packets are retained, NEVER guessed.
%
%   Options:
%     "Address"      BLE address; otherwise use pocketlabPair's saved address
%     "Quiet"        true/false (default false)
%     "SaveFile"     full/relative .mat path for raw capture (default "")
%     "DecodePacked" true/false (default true); false = raw probe only
%     "OnUpdate"    callback @(t,data) for live plotting (default [])
%     "ShouldStop"  callback @() logical for early stop (default [])
%     "UpdateInterval_s" minimum callback interval (default 0.25)
%     "ForceOnline" issue 6C 00 before streaming (default false)
%
%   With OnUpdate/ShouldStop, data continue to be saved to SaveFile on
%   ordinary early stop. Live plotting uses nominal time, not device-side
%   sample timestamps. Memory Mode and streaming must NOT run together.
%
%   PHYSICAL VALIDATION: Acceleration + gyroscope at 20 Hz has been
%   checked on Voyager 2 hardware using stationary, dynamic, and
%   independent gyroscope reference measurements. Other combinations and
%   rates remain experimental. Sample times are nominal (0:N-1)/Fs;
%   hardware timestamp accuracy and precise synchronization are unverified.
%   Use pocketlabRead for the established single-sensor acquisition path.

validateattributes(recordTime,{'numeric'}, ...
    {'scalar','real','positive','finite'},mfilename,'recordTime');
validateattributes(Fs,{'numeric'}, ...
    {'scalar','real','positive','finite'},mfilename,'Fs');
sensorNames = lower(strtrim(string(sensorNames(:).')));
if numel(sensorNames) < 2 || any(ismissing(sensorNames)) || ...
        any(strlength(sensorNames)==0)
    error('Supply at least two sensor names, e.g. ["acceleration","gyroscope"].');
end

aliases = containers.Map( ...
    {'accel','accelerometer','gyro','mag','temp'}, ...
    {'acceleration','acceleration','gyroscope','magnetometer','temperature'});
for k=1:numel(sensorNames)
    key=char(sensorNames(k));
    if isKey(aliases,key), sensorNames(k)=string(aliases(key)); end
end
if numel(unique(sensorNames))~=numel(sensorNames)
    error('Sensor names must be distinct.');
end

registry = pocketlabSensorRegistry();
sensors = repmat(registry.acceleration,1,numel(sensorNames));
for k=1:numel(sensorNames)
    key=char(sensorNames(k));
    if ~isfield(registry,key)
        error('Unknown sensor "%s". Run pocketlabSensors to list names.',key);
    end
    sensors(k)=registry.(key);
end

% Combined sensor configuration is a BITWISE OR, not numerical addition.
mask=uint32(0);
for k=1:numel(sensors)
    if bitand(mask,sensors(k).ConfigValue)~=0
        error('Overlapping configuration bits; cannot combine requested sensors.');
    end
    mask=bitor(mask,sensors(k).ConfigValue);
end

p=inputParser;
addParameter(p,'Address',"",@(x)ischar(x)||isstring(x));
addParameter(p,'Quiet',false,@(x)islogical(x)||isnumeric(x));
addParameter(p,'SaveFile',"",@(x)ischar(x)||isstring(x));
addParameter(p,'DecodePacked',true,@(x)islogical(x)||isnumeric(x));
addParameter(p,'OnUpdate',[],@(x)isempty(x)||isa(x,'function_handle'));
addParameter(p,'ShouldStop',[],@(x)isempty(x)||isa(x,'function_handle'));
addParameter(p,'UpdateInterval_s',0.25,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=0.1);
addParameter(p,'ForceOnline',false,@(x)islogical(x)&&isscalar(x));
parse(p,varargin{:});
address=string(p.Results.Address);
quiet=logical(p.Results.Quiet);
saveFile=string(p.Results.SaveFile);
decodePacked=logical(p.Results.DecodePacked);
onUpdate=p.Results.OnUpdate;
shouldStop=p.Results.ShouldStop;
updateInterval_s=p.Results.UpdateInterval_s;
forceOnline=p.Results.ForceOnline;

if strlength(address)==0
    driverDir=fileparts(mfilename('fullpath'));
    pairingFile=fullfile(driverDir,'pocketlab_pairing.mat');
    if ~isfile(pairingFile)
        error('Pair using pocketlabPair, or specify "Address",address.');
    end
    S=load(pairingFile,'pairing');
    address=string(S.pairing.Address);
end

freqCommand=localFrequencyCommand(Fs);
enableCommand=uint8([hex2dec('6E') ...
    bitand(mask,uint32(255)) ...
    bitand(bitshift(mask,-8),uint32(255)) ...
    bitand(bitshift(mask,-16),uint32(255)) ...
    bitand(bitshift(mask,-24),uint32(255))]);

% Explicitly start a fresh packet buffer for this run.
data=struct();
for k=1:numel(sensorNames)
    data.(char(sensorNames(k)))=zeros(0,sensors(k).NumChannels);
end
packetTimes=NaT(0,1);
rawPackets=cell(0,1);
packetLengths=zeros(0,1);
decodedPackets=0;
undecodedPackets=0;
validatedConfiguration=(numel(sensorNames)==2 && Fs==20 && ...
    all(ismember(["acceleration","gyroscope"],sensorNames)));

if ~quiet
    fprintf('\nPocketLab Voyager 2 - Multi-Sensor Acquisition\n');
    fprintf('----------------------------------------------\n');
    fprintf('Sensors: %s | Fs: %g Hz | Duration: %g s\n', ...
        strjoin(cellstr(sensorNames),', '),Fs,recordTime);
    fprintf('Combined config: 0x%s\n',dec2hex(mask,8));
    if validatedConfiguration
        fprintf('Validation: Acceleration/Gyroscope channel mapping checked at 20 Hz.\n');
    else
        fprintf('Validation: This sensor combination/rate is experimental.\n');
    end
    fprintf('Timing: Nominal sample timestamps; hardware timing unverified.\n');
end

serviceUUID="152FDEA4-28A1-11ED-A261-0242AC120002";
txUUID="152FDEA5-28A1-11ED-A261-0242AC120002";
rxUUID="152FDEA6-28A1-11ED-A261-0242AC120002";

b=ble(address);
tx=characteristic(b,serviceUUID,txUUID);
rx=characteristic(b,serviceUUID,rxUUID);
subscribe(rx);
cleanupObj=onCleanup(@() localCleanup(tx,rx));
pause(0.15);

% Explicitly request streaming/online transport only when the caller
% opts in (e.g. GUI live mode after a previous offline memory session).
if forceOnline
    write(tx,uint8([108 0]),"withresponse");
    pause(0.10);
end
write(tx,uint8([hex2dec('60') hex2dec('01')]),"withresponse");
pause(0.10);
% A single combined enable request replaces the single-sensor command.
write(tx,enableCommand,"withresponse");
pause(0.10);
write(tx,freqCommand,"withresponse");
pause(0.10);

% Text progress indicator, throttled to approximately once per second.
progressLastSecond=-1;
if ~quiet
    fprintf('Recording: [%s] %3d%% | %d / %g s',repmat('-',1,20),0,0,recordTime);
end
startClock=tic;
lastUpdateClock=tic;
lastUICheckClock=tic;
stopRequested=false;
while toc(startClock)<recordTime
    % drawnow pumps the UI event queue so Stop Live can set its flag even
    % while acquisition runs in the Start Live button callback.
    if ~isempty(shouldStop)
        if toc(lastUICheckClock)>=0.10
            % Process pending button events promptly: a throttled drawnow
            % may defer callback dispatch while the plot is busy.
            drawnow;
            lastUICheckClock=tic;
        end
        if logical(shouldStop())
            stopRequested=true;
            break
        end
    end
    if ~quiet
        elapsedProgress=min(recordTime,toc(startClock));
        progressSecond=floor(elapsedProgress);
        if progressSecond>progressLastSecond
            progressLastSecond=progressSecond;
            fraction=elapsedProgress/recordTime;
            filled=min(20,floor(20*fraction));
            fprintf('\rRecording: [%s%s] %3.0f%% | %.0f / %g s', ...
                repmat('#',1,filled),repmat('-',1,20-filled), ...
                floor(100*fraction),floor(elapsedProgress),recordTime);
        end
    end
    try
        [packet,packetTimestamp]=read(rx);
        raw=uint8(packet(:).');
        rawPackets{end+1,1}=raw; %#ok<AGROW>
        packetTimes(end+1,1)=packetTimestamp; %#ok<AGROW>
        packetLengths(end+1,1)=numel(raw); %#ok<AGROW>

        if decodePacked
            [block,ok]=pocketlabDecodeMultiPacket(raw,sensors);
        else
            block=[];
            ok=false;
        end
        if ok
            firstColumn=1;
            for k=1:numel(sensorNames)
                n=sensors(k).NumChannels;
                name=char(sensorNames(k));
                data.(name)=[data.(name); double(block(:,firstColumn:firstColumn+n-1))]; %#ok<AGROW>
                firstColumn=firstColumn+n;
            end
            decodedPackets=decodedPackets+1;
            if ~isempty(onUpdate) && toc(lastUpdateClock)>=updateInterval_s
                count=size(data.(char(sensorNames(1))),1);
                tPreview=(0:count-1)'/Fs;
                try
                    onUpdate(tPreview,data);
                catch displayError
                    warning('PocketLab:LiveDisplayError', ...
                        'Live display callback failed: %s. Acquisition continues.', ...
                        displayError.message);
                    onUpdate=[];  % Never discard sensor capture due to UI.
                end
                lastUpdateClock=tic;
            end
        else
            undecodedPackets=undecodedPackets+1;
        end
    catch ME
        if ~b.Connected
            error('PocketLab disconnected during multi-sensor acquisition.');
        elseif contains(ME.message,'has not sent new data','IgnoreCase',true)
            pause(0.002);
        else
            rethrow(ME);
        end
    end
end
elapsed_s=toc(startClock);
% Always publish the final decoded data once (including early stop).
if ~isempty(onUpdate) && decodePacked
    count=size(data.(char(sensorNames(1))),1);
    try
        onUpdate((0:count-1)'/Fs,data);
    catch displayError
        warning('PocketLab:LiveDisplayError', ...
            'Final live display failed: %s. Capture can still be saved.', ...
            displayError.message);
    end
end
if ~quiet
    fprintf('\rRecording: [%s] 100%% | %g / %g s\n',repmat('#',1,20),recordTime,recordTime);
end
clear cleanupObj  % Disables all enabled sensors and unsubscribes.

nSamples=size(data.(char(sensorNames(1))),1);
if decodePacked
    t=(0:nSamples-1)'/Fs; % Nominal sample timeline ONLY.
else
    t=zeros(0,1);
end

info=struct();
info.Name=string(b.Name);
info.Address=address;
info.Sensors=sensorNames;
info.ChannelLabels={sensors.Labels};
info.Units=string([sensors.Unit]);
info.ConfigurationMask=mask;
info.Command=enableCommand;
info.RequestedRate_Hz=Fs;
info.RequestedTime_s=recordTime;
info.AcquisitionElapsed_s=elapsed_s;
info.StoppedByUser=stopRequested;
info.PacketCount=numel(rawPackets);
info.PacketLengths=packetLengths;
info.PacketTimestamps=packetTimes;
info.RawPackets=rawPackets;
info.DecodedPacketCount=decodedPackets;
info.UndecodedPacketCount=undecodedPackets;
info.CandidateSampleCount=nSamples;
info.SampleCount=nSamples;
info.DecodingIsVerified=validatedConfiguration && decodePacked && decodedPackets>0;
info.SynchronizationIsVerified=false;
info.AssumedFrame="6-byte header, then ordered float32 sensor values";
info.SaveFile=saveFile;

% Only warn when there is an actual acquisition/decoding concern.
% Experimental validation status stays in info.DecodingIsVerified and in
% the driver documentation; it is not a per-run warning.
if decodePacked && decodedPackets==0
    warning('PocketLab:UnrecognizedMultiPackets', ...
        ['No packets matched the assumed combined format. ' ...
        'Inspect info.PacketLengths and info.RawPackets. ' ...
        'Do NOT interpret empty results as missing sensor motion.']);
end

if strlength(saveFile)>0
    save(char(saveFile),'t','data','info');
end

if ~quiet
    fprintf('Packets: %d | data packets: %d | other packets: %d\n', ...
        info.PacketCount,decodedPackets,undecodedPackets);
    fprintf('Samples: %d\n',nSamples);
    if strlength(saveFile)>0
        fprintf('Raw probe saved: %s\n',saveFile);
    end
end
end

function cmd=localFrequencyCommand(Fs)
rates=[1/60,1/30,1/15,1/10,1/5,1,5,10,20,25,50,250];
instructions=uint32([hex2dec('EA600001'),hex2dec('75300001'), ...
    hex2dec('3A980001'),hex2dec('27100001'),hex2dec('13880001'), ...
    hex2dec('03E80001'),hex2dec('00C80001'),hex2dec('00C80002'), ...
    hex2dec('00C80004'),hex2dec('00780003'),hex2dec('00780006'), ...
    hex2dec('00480012')]);
[err,idx]=min(abs(rates-Fs));
if err>max(1e-12,1e-9*max(1,abs(Fs)))
    error('Unsupported sample rate; check pocketlabRead documentation.');
end
v=instructions(idx);
b0=uint8(bitand(v,uint32(255)));
b1=uint8(bitand(bitshift(v,-8),uint32(255)));
b2=uint8(bitand(bitshift(v,-16),uint32(255)));
b3=uint8(bitand(bitshift(v,-24),uint32(255)));
cmd=uint8([hex2dec('70') b2 b3 b0 b1]);
end

function localCleanup(tx,rx)
try
    write(tx,uint8([hex2dec('6E') 0 0 0 0]),"withresponse");
catch
end
try
    unsubscribe(rx);
catch
end
end
