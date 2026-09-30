function [t,Y,info] = pocketlabRead(sensorName,recordTime,Fs,varargin)
%POCKETLABREAD Read one PocketLab Voyager 2 sensor directly over BLE.
%
%   [t,Y] = pocketlabRead(sensorName,recordTime,Fs)
%   [t,Y,info] = pocketlabRead(...)
%
% Examples
%   [t,A] = pocketlabRead("acceleration",10,20);
%   [t,W] = pocketlabRead("gyroscope",10,20);
%   [t,R] = pocketlabRead("rangefinder",10,20);
%   [t,T] = pocketlabRead("temperature",30,1);
%
% Options
%   "Address"   Explicit BLE address instead of saved pairing.
%   "Quiet"     true/false
%   "Units"     Acceleration only: "g" or "m/s^2"
%   "ExternalMode"  External sensor only:
%                   "voltage","resistance","current","temperature"
%   "SuppressExperimentalWarning"  true/false
%
% IMPORTANT
%   Acceleration has been physically validated.
%   Other sensor masks/value lengths come from PocketLab's public device
%   configuration but their packet decoding and engineering units have not
%   yet been physically validated in this MATLAB driver.
%
% This version intentionally reads ONE sensor at a time. That keeps packet
% parsing simple and is appropriate for classroom experiments.

validateattributes(recordTime, {'numeric'}, ...
    {'scalar','real','positive','finite'}, mfilename, 'recordTime');
validateattributes(Fs, {'numeric'}, ...
    {'scalar','real','positive','finite'}, mfilename, 'Fs');

p = inputParser;
addParameter(p,'Address',"",@(x)ischar(x) || isstring(x));
addParameter(p,'Quiet',false,@(x)islogical(x) || isnumeric(x));
addParameter(p,'Units',"native",@(x)ischar(x) || isstring(x));
addParameter(p,'ExternalMode',"voltage",@(x)ischar(x) || isstring(x));
addParameter(p,'SuppressExperimentalWarning',false, ...
    @(x)islogical(x) || isnumeric(x));
parse(p,varargin{:});

address = string(p.Results.Address);
quiet = logical(p.Results.Quiet);
unitsRequested = string(p.Results.Units);
externalMode = lower(string(p.Results.ExternalMode));
suppressWarning = logical(p.Results.SuppressExperimentalWarning);

sensorKey = localNormalizeSensorName(sensorName);
registry = pocketlabSensorRegistry();

if ~isfield(registry,sensorKey)
    error('Unknown sensor "%s". Run pocketlabSensors to see supported names.', ...
        sensorName);
end

sensor = registry.(sensorKey);

if ~sensor.Validated && ~suppressWarning
    warning('PocketLab:ExperimentalSensor', ...
        ['"%s" is included from the Voyager 2 public device configuration, ' ...
         'but has not yet been physically validated with this MATLAB driver.'], ...
        sensor.DisplayName);
end

driverDir   = fileparts(mfilename('fullpath'));
pairingFile = fullfile(driverDir,'pocketlab_pairing.mat');

pairing = struct;

if strlength(address) == 0
    if ~isfile(pairingFile)
        error(['No PocketLab pairing was found. Run pocketlabPair first, ' ...
            'or supply "Address",address explicitly.']);
    end

    S = load(pairingFile,'pairing');
    pairing = S.pairing;
    address = string(pairing.Address);
end

cmdFrequency = localFrequencyCommand(Fs);
cmdSensor = localEnableCommand(sensor.ConfigValue);

serviceUUID = "152FDEA4-28A1-11ED-A261-0242AC120002";
txUUID      = "152FDEA5-28A1-11ED-A261-0242AC120002";
rxUUID      = "152FDEA6-28A1-11ED-A261-0242AC120002";

if ~quiet
    fprintf('\nPocketLab Voyager 2 acquisition\n');
    fprintf('-------------------------------\n');
    if isfield(pairing,'Label') && strlength(string(pairing.Label)) > 0
        fprintf('Device      : %s\n',string(pairing.Label));
    end
    fprintf('Sensor      : %s\n',sensor.DisplayName);
    fprintf('BLE address : %s\n',address);
    fprintf('Sample rate : %g Hz\n',Fs);
    fprintf('Record time : %g s\n',recordTime);
    fprintf('Connecting...\n');
end

b = ble(address);

if ~quiet
    fprintf('Connected to: %s\n',b.Name);
end

tx = characteristic(b,serviceUUID,txUUID);
rx = characteristic(b,serviceUUID,rxUUID);

subscribe(rx);
pause(0.15);

cleanupObj = onCleanup(@() localCleanup(tx,rx));

% Start polling.
write(tx,uint8([hex2dec('60') hex2dec('01')]),"withresponse");
pause(0.10);

% Some external sensor modes require an additional secondary command.
if sensorKey == "external"
    modeMap = struct( ...
        'voltage',uint8([hex2dec('78') hex2dec('00')]), ...
        'resistance',uint8([hex2dec('78') hex2dec('01')]), ...
        'current',uint8([hex2dec('78') hex2dec('02')]), ...
        'temperature',uint8([hex2dec('78') hex2dec('03')]));

    if ~isfield(modeMap,externalMode)
        error(['ExternalMode must be "voltage", "resistance", ' ...
               '"current", or "temperature".']);
    end

    write(tx,modeMap.(externalMode),"withresponse");
    pause(0.10);
end

% Enable one sensor.
write(tx,cmdSensor,"withresponse");
pause(0.10);

% Set sample rate.
write(tx,cmdFrequency,"withresponse");
pause(0.10);

if ~quiet
    fprintf('Recording...\n');
end

Yraw = zeros(0,sensor.NumChannels,'single');
packetTimes = NaT(0,1);
packetBytes = zeros(0,1);
rawPackets = cell(0,1);
invalidPackets = 0;

startClock = tic;

while toc(startClock) < recordTime
    try
        [packet,packetTimestamp] = read(rx);
        raw = uint8(packet);

        rawPackets{end+1,1} = raw; %#ok<AGROW>
        packetTimes(end+1,1) = packetTimestamp; %#ok<AGROW>
        packetBytes(end+1,1) = numel(raw); %#ok<AGROW>

        % Acceleration packets have been observed to contain a 6-byte
        % header followed by packed float32 values. The same framing is
        % used here provisionally for the other single-sensor streams.
        if numel(raw) > 6
            payload = raw(7:end);

            nComplete = floor(numel(payload)/sensor.ValueLength);

            if nComplete > 0
                payload = payload(1:nComplete*sensor.ValueLength);

                values = typecast(payload,'single');

                expectedValues = nComplete*sensor.NumChannels;

                if numel(values) >= expectedValues
                    values = values(1:expectedValues);
                    block = reshape(values,sensor.NumChannels,[]).';
                    Yraw = [Yraw; block]; %#ok<AGROW>
                else
                    invalidPackets = invalidPackets + 1;
                end
            else
                invalidPackets = invalidPackets + 1;
            end
        else
            invalidPackets = invalidPackets + 1;
        end

    catch ME
        if ~b.Connected
            error('PocketLab disconnected during acquisition.');
        end

        if contains(ME.message,'has not sent new data','IgnoreCase',true)
            pause(0.002);
        else
            rethrow(ME);
        end
    end
end

clear cleanupObj

N = size(Yraw,1);
t = (0:N-1)'/Fs;
Y = double(Yraw);

unitOut = sensor.Unit;

% Only acceleration unit conversion is currently implemented/validated.
if sensorKey == "acceleration"
    if strcmpi(unitsRequested,"m/s^2") || strcmpi(unitsRequested,"m/s2")
        Y = Y*9.80665;
        unitOut = "m/s^2";
    elseif strcmpi(unitsRequested,"g") || strcmpi(unitsRequested,"native")
        unitOut = "g";
    else
        error('For acceleration, Units must be "g", "m/s^2", or "native".');
    end
elseif ~strcmpi(unitsRequested,"native")
    warning('PocketLab:UnitsNotValidated', ...
        ['Engineering-unit conversion for "%s" is not yet validated. ' ...
         'Returning native decoded values.'],sensor.DisplayName);
end

info = struct;
info.Name = string(b.Name);
info.Address = address;
info.SensorKey = sensorKey;
info.Sensor = sensor.DisplayName;
info.ChannelLabels = sensor.Labels;
info.Unit = unitOut;
info.Validated = sensor.Validated;
info.SampleRate_Hz = Fs;
info.RequestedTime_s = recordTime;
info.SamplesReceived = N;
info.PacketCount = numel(packetBytes);
info.PacketBytes = packetBytes;
info.PacketTimestamps = packetTimes;
info.InvalidPacketCount = invalidPackets;
info.RawPackets = rawPackets;

if N > 0
    info.SensorDuration_s = (N-1)/Fs;
else
    info.SensorDuration_s = 0;
end

info.SampleRecoveryFraction = N/(recordTime*Fs);

if ~quiet
    fprintf('Done.\n');
    fprintf('Samples received : %d\n',N);
    fprintf('Packets received : %d\n',info.PacketCount);
    fprintf('Invalid packets  : %d\n',invalidPackets);
    if N > 0
        fprintf('Sensor duration  : %.3f s\n',info.SensorDuration_s);
    end
    if ~sensor.Validated
        fprintf('Status           : EXPERIMENTAL / not yet physically validated\n');
    end
    fprintf('\n');
end
end


function key = localNormalizeSensorName(name)
name = lower(strtrim(string(name)));

aliases = containers.Map( ...
    {'accel','accelerometer','acceleration', ...
     'gyro','gyroscope', ...
     'mag','magnetometer', ...
     'heading','pitch','roll','quaternion','quat', ...
     'range','rangefinder','distance', ...
     'displacement','velocity','rangeacceleration', ...
     'external','extsensor', ...
     'temperature','temp','pressure','humidity','altitude', ...
     'dewpoint','heatindex','uv','uvlight', ...
     'ambient','ambientlight','ir','irlight'}, ...
    {'acceleration','acceleration','acceleration', ...
     'gyroscope','gyroscope', ...
     'magnetometer','magnetometer', ...
     'heading','pitch','roll','quaternion','quaternion', ...
     'rangefinder','rangefinder','rangefinder', ...
     'displacement','velocity','rangeacceleration', ...
     'external','external', ...
     'temperature','temperature','pressure','humidity','altitude', ...
     'dewpoint','heatindex','uvlight','uvlight', ...
     'ambientlight','ambientlight','irlight','irlight'});

if ~isKey(aliases,char(name))
    key = name;
else
    key = string(aliases(char(name)));
end
end


function cmd = localEnableCommand(configValue)
v = uint32(configValue);

b0 = uint8(bitand(v,uint32(255)));
b1 = uint8(bitand(bitshift(v,-8), uint32(255)));
b2 = uint8(bitand(bitshift(v,-16),uint32(255)));
b3 = uint8(bitand(bitshift(v,-24),uint32(255)));

cmd = uint8([hex2dec('6E') b0 b1 b2 b3]);
end


function cmd = localFrequencyCommand(Fs)
rates = [ ...
    1/60, 1/30, 1/15, 1/10, 1/5, ...
    1, 5, 10, 20, 25, 50, 250];

instructions = uint32([ ...
    hex2dec('EA600001'), ...
    hex2dec('75300001'), ...
    hex2dec('3A980001'), ...
    hex2dec('27100001'), ...
    hex2dec('13880001'), ...
    hex2dec('03E80001'), ...
    hex2dec('00C80001'), ...
    hex2dec('00C80002'), ...
    hex2dec('00C80004'), ...
    hex2dec('00780003'), ...
    hex2dec('00780006'), ...
    hex2dec('00480012')]);

[err,idx] = min(abs(rates-Fs));
tol = max(1e-12,1e-9*max(1,abs(Fs)));

if err > tol
    error(['Unsupported sample rate. Supported values are: ' ...
        '1/60, 1/30, 1/15, 1/10, 1/5, 1, 5, 10, 20, 25, 50, 250 Hz.']);
end

instruction = instructions(idx);

b0 = uint8(bitand(instruction,uint32(255)));
b1 = uint8(bitand(bitshift(instruction,-8), uint32(255)));
b2 = uint8(bitand(bitshift(instruction,-16),uint32(255)));
b3 = uint8(bitand(bitshift(instruction,-24),uint32(255)));

cmd = uint8([hex2dec('70') b2 b3 b0 b1]);
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
