function info = pocketlabMemoryProbe(mode,varargin)
%POCKETLABMEMORYPROBE Conservative Voyager 2 memory status/raw download.
%
%  info = pocketlabMemoryProbe("status")
%  info = pocketlabMemoryProbe("download","SaveFile","memory_probe.mat")
%
%  EXPERIMENTAL: Inferred from PocketLab Notebook JavaScript and observed
%  Edge BLE command logs for Voyager 2 (firmware VP.1.2). Hardware execution
%  of THIS MATLAB function has not yet been verified.
%
%  The download preserves raw packets. It does not interpret sample times
%  as hardware timestamps and NEVER sends the memory erase command 4C 97.
%
%  Options: "Address", "SaveFile", "MaxDuration_s", "IdleTimeout_s", "MaxPackets", "Quiet".
%  Disconnect PocketLab Notebook before using this function.

if nargin<1 || strlength(string(mode))==0
    mode="status";
end
mode=lower(string(mode));
if ~isscalar(mode) || ~ismember(mode,["status","download"])
    error('Mode must be "status" or "download".');
end

p=inputParser;
addParameter(p,'Address',"",@(x)ischar(x)||isstring(x));
addParameter(p,'SaveFile',"",@(x)ischar(x)||isstring(x));
addParameter(p,'MaxDuration_s',180,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'IdleTimeout_s',15,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'MaxPackets',10000,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1&&x==floor(x));
addParameter(p,'Quiet',false,@(x)islogical(x)||isnumeric(x));
parse(p,varargin{:});
address=string(p.Results.Address);
saveFile=string(p.Results.SaveFile);
quiet=logical(p.Results.Quiet);

if strlength(address)==0
    driverDir=fileparts(mfilename('fullpath'));
    pairingFile=fullfile(driverDir,'pocketlab_pairing.mat');
    if ~isfile(pairingFile)
        error('Run pocketlabPair or provide "Address",address.');
    end
    S=load(pairingFile,'pairing');
    address=string(S.pairing.Address);
end

svc="152FDEA4-28A1-11ED-A261-0242AC120002";
txId="152FDEA5-28A1-11ED-A261-0242AC120002";
rxId="152FDEA6-28A1-11ED-A261-0242AC120002";

b=ble(address);
tx=characteristic(b,svc,txId);
rx=characteristic(b,svc,rxId);

info=struct();
info.DeviceAddress=address;
info.Mode=mode;
info.Source="PocketLab Notebook voyagerpro JS + observed BLE logs";
info.HardwareValidated=false;
info.Timing="Not hardware timestamped";
info.RawPackets={};
info.PacketTimestamps=NaT(0,1);
info.PacketLengths=zeros(0,1);
info.FlashPacketCount=0;
info.EndMarkerSeen=false;
info.UserSpacePacket=uint8([]);
info.MemoryRateResponse=uint8([]);
info.MemoryChunkResponse=uint8([]);
info.FrequencyInstruction=NaN;
info.MemoryRateValid=false;
info.ChunkLength=NaN;
info.NominalChunkInterval_s=NaN;
info.NominalSampleInterval_s=NaN;

% The official app writes status command 23 twice, then reads RX.
write(tx,uint8(35),"withresponse");
pause(0.10);
write(tx,uint8(35),"withresponse");
pause(0.10);
statusRaw=uint8(read(rx));
info.StatusResponse=statusRaw;
info.MemoryFlags=NaN;
info.MemoryState="Unknown";
if numel(statusRaw)>=3
    flags=statusRaw(3);
    info.MemoryFlags=double(flags);
    if bitand(flags,uint8(8))~=0
        info.MemoryState="Recording";
    elseif bitand(flags,uint8(1))~=0
        info.MemoryState="Recorded";
    else
        info.MemoryState="Empty";
    end
end
if ~quiet
    fprintf('Voyager 2 memory status: %s | RX: %s\n', ...
        info.MemoryState,localHex(statusRaw));
end

if mode=="status"
    if strlength(saveFile)>0, save(char(saveFile),'info'); end
    return
end

% Enter offline mode. Restore online mode even if acquisition fails.
write(tx,uint8([108 1]),"withresponse");
pause(0.10);
cleanupObj=onCleanup(@()localRestore(tx,rx));

% Read memory sampling settings, then chunk length.
write(tx,uint8(41),"withresponse"); % 29
pause(0.10);
rateResponse=uint8(read(rx));
info.MemoryRateResponse=rateResponse;
if numel(rateResponse)>=6
    highWord=double(rateResponse(3))+256*double(rateResponse(4));
    lowWord=double(rateResponse(5))+256*double(rateResponse(6));
    instruction=highWord*65536+lowWord;
    % Reject invalid/uninitialized instructions (notably FF FF FF FF).
    % These values are taken from the Voyager 2 web-app rate table.
    supportedInstructions=[3932160001,1966080001,983040001, ...
        655360001,327680001,65536001,13107201,13107202, ...
        9830403,7864323,7864326,4718610];
    if any(instruction==supportedInstructions)
        info.FrequencyInstruction=instruction;
        info.MemoryRateValid=true;
        info.NominalChunkInterval_s=highWord/1000;
        info.NominalSampleInterval_s=highWord/(1000*lowWord);
    else
        warning('PocketLab:InvalidMemoryRate', ...
            ['Memory rate response is not a recognized Voyager 2 rate ' ...
             '(raw: %s). Sample timing remains unknown; raw flash data ' ...
             'can still be downloaded.'],localHex(rateResponse));
    end
else
    warning('PocketLab:MemoryRateResponse','Memory rate response shorter than 6 bytes.');
end

write(tx,uint8(39),"withresponse"); % 27
pause(0.10);
chunkResponse=uint8(read(rx));
info.MemoryChunkResponse=chunkResponse;
if numel(chunkResponse)>=3
    info.ChunkLength=double(chunkResponse(3));
else
    warning('PocketLab:MemoryChunkResponse','Memory chunk response shorter than 3 bytes.');
end
if ~quiet
    if info.MemoryRateValid
        fprintf('Memory instruction: %.0f | chunk bytes: %g | nominal dt: %g s\n', ...
            info.FrequencyInstruction,info.ChunkLength,info.NominalSampleInterval_s);
    else
        fprintf('Memory rate: UNKNOWN | chunk bytes: %g (raw rate: %s)\n', ...
            info.ChunkLength,localHex(rateResponse));
    end
end

subscribe(rx);
pause(0.10);

% Optional user-space metadata download. Do not erase user-space storage.
write(tx,uint8([76 129]),"withresponse"); % 4C 81
userClock=tic;
while toc(userClock)<2
    try
        [packet,~]=read(rx);
        raw=uint8(packet(:).');
        if ~isempty(raw) && raw(1)==149 % 95
            info.UserSpacePacket=raw;
            break
        end
    catch ME
        if localNoNewData(ME)
            pause(0.02);
        else
            rethrow(ME);
        end
    end
end

% Start reading flash. Packet 96 contains recorded samples; notification
% 11 with bit 0x10 set in its third byte denotes download completion.
write(tx,uint8([76 118]),"withresponse"); % 4C 76
rawPackets=cell(0,1);
packetTimes=NaT(0,1);
packetLengths=zeros(0,1);
flashCount=0;
complete=false;
downloadClock=tic;
lastPacketClock=tic;
lastProgressClock=tic;
idleTimedOut=false;
while toc(downloadClock)<p.Results.MaxDuration_s && ...
      numel(rawPackets)<p.Results.MaxPackets
    if toc(lastPacketClock)>=p.Results.IdleTimeout_s
        idleTimedOut=true;
        break
    end
    if ~quiet && toc(lastProgressClock)>5
        fprintf('Downloading memory: %d packets, %d flash (%.1f s elapsed)\n', ...
            numel(rawPackets),flashCount,toc(downloadClock));
        lastProgressClock=tic;
    end
    try
        [packet,stamp]=read(rx);
        raw=uint8(packet(:).');
        if isempty(raw), continue; end
        lastPacketClock=tic;
        rawPackets{end+1,1}=raw; %#ok<AGROW>
        packetTimes(end+1,1)=stamp; %#ok<AGROW>
        packetLengths(end+1,1)=numel(raw); %#ok<AGROW>
        if raw(1)==150
            flashCount=flashCount+1;
        elseif raw(1)==17 && numel(raw)>=3 && bitand(raw(3),uint8(16))~=0
            complete=true;
            break
        end
    catch ME
        if localNoNewData(ME)
            pause(0.005);
        else
            rethrow(ME);
        end
    end
end
info.RawPackets=rawPackets;
info.PacketTimestamps=packetTimes;
info.PacketLengths=packetLengths;
info.FlashPacketCount=flashCount;
info.EndMarkerSeen=complete;
info.IdleTimedOut=idleTimedOut;
info.AcquisitionElapsed_s=toc(downloadClock);
if ~quiet
    fprintf('Memory raw download: %d packets (%d flash), end marker: %d\n', ...
        numel(rawPackets),flashCount,complete);
end
if ~complete
    if idleTimedOut
        warning('PocketLab:MemoryDownloadIdle', ...
            'No BLE packets for %.0f s; stopped waiting. Received %d flash packets.', ...
            p.Results.IdleTimeout_s,flashCount);
    else
        warning('PocketLab:MemoryDownloadIncomplete', ...
            'End marker not observed. Download may be incomplete.');
    end
end

% Cleanup puts device back online and unsubscribes. No erase is sent.
clear cleanupObj
if strlength(saveFile)>0, save(char(saveFile),'info'); end
end

function tf=localNoNewData(ME)
tf=contains(ME.message,'has not sent new data','IgnoreCase',true) || ...
   contains(ME.message,'No data','IgnoreCase',true);
end

function localRestore(tx,rx)
try
    unsubscribe(rx);
catch
end
try
    write(tx,uint8([108 0]),"withresponse"); % 6C 00
catch
end
end

function s=localHex(raw)
if isempty(raw)
    s="";
else
    s=strjoin(compose("%02X",raw)," ");
end
end
