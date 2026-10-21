function info = pocketlabMemoryProbe(mode,varargin)
%POCKETLABMEMORYPROBE Conservative Voyager 2 memory status/raw download.
%
%  info = pocketlabMemoryProbe("status")
%  info = pocketlabMemoryProbe("download","SaveFile","memory_probe.mat")
%
%  Protocol inferred from PocketLab Notebook JS and BLE logs; memory
%  status, Flash reading and completion markers tested on VP.1.2.
%  Repeatability of the completion marker remains under investigation.
%
%  The download preserves raw packets. It does not interpret sample times
%  as hardware timestamps and NEVER sends the memory erase command 4C 97.
%
%  Options: "Address", "SaveFile", "MaxDuration_s", "IdleTimeout_s",
%           "MaxPaddingWait_s", "MaxPackets", "Quiet", "WarnOnIncomplete".
%  MaxPaddingWait_s (legacy name) limits elapsed time since last actual
%  Flash frame (0x96). Status and unrelated BLE packets are not progress.
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
addParameter(p,'MaxPaddingWait_s',25,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0);
addParameter(p,'MaxPackets',10000,@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>=1&&x==floor(x));
addParameter(p,'Quiet',false,@(x)islogical(x)||isnumeric(x));
addParameter(p,'WarnOnIncomplete',true,@(x)islogical(x)&&isscalar(x));
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
info.MemoryRateUninitialized=false;
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
    elseif all(rateResponse(3:6)==uint8(255))
        % Frequently observed on MATLAB-started recordings. These bytes
        % mean rate metadata are unset, NOT that saved Flash is corrupt.
        info.MemoryRateUninitialized=true;
        if ~quiet
            fprintf(['Memory rate metadata unset (FF FF FF FF); ' ...
                'nominal rate must come from the recording settings.\n']);
        end
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
lastFlashClock=tic;
lastProgressClock=tic;
idleTimedOut=false;
paddingTimedOut=false;
paddingCount=0;
otherCount=0;
endStatusCount=0;
while toc(downloadClock)<p.Results.MaxDuration_s && ...
      numel(rawPackets)<p.Results.MaxPackets
    if toc(lastPacketClock)>=p.Results.IdleTimeout_s
        idleTimedOut=true;
        break
    end
    % Non-FF packets can be unrelated background BLE traffic.
    % Only actual 0x96 Flash notifications extend the completion grace.
    % Some successful end markers arrive many seconds after last Flash.
    if toc(lastFlashClock)>=p.Results.MaxPaddingWait_s
        paddingTimedOut=true;
        break
    end
    if ~quiet && toc(lastProgressClock)>5
        fprintf(['Downloading memory: %d packets, %d flash, ' ...
            '%d FF padding, %d other (%.1f s elapsed)\n'], ...
            numel(rawPackets),flashCount,paddingCount, ...
            otherCount,toc(downloadClock));
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
            lastFlashClock=tic;
        elseif all(raw==uint8(255))
            paddingCount=paddingCount+1;
        elseif raw(1)==17 && numel(raw)>=3
            endStatusCount=endStatusCount+1;
            if bitand(raw(3),uint8(16))~=0
                complete=true;
                break
            end
            otherCount=otherCount+1;
        else
            otherCount=otherCount+1;
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
info.PaddingTimedOut=paddingTimedOut;
info.PaddingPacketCount=paddingCount;
info.OtherPacketCount=otherCount;
info.StatusPacketCount=endStatusCount;
info.NoFlashTimeout_s=p.Results.MaxPaddingWait_s;
if complete
    info.DownloadStopReason="EndMarker";
elseif paddingTimedOut
    info.DownloadStopReason="NoFlashProgressTimeout";
elseif idleTimedOut
    info.DownloadStopReason="NoBLEPacketsTimeout";
elseif numel(rawPackets)>=p.Results.MaxPackets
    info.DownloadStopReason="MaxPackets";
else
    info.DownloadStopReason="MaxDuration";
end
info.AcquisitionElapsed_s=toc(downloadClock);
if ~quiet
    fprintf(['Memory raw download: %d packets (%d flash, %d FF padding, ' ...
        '%d other), end marker: %d, stop: %s\n'], ...
        numel(rawPackets),flashCount,paddingCount,otherCount, ...
        complete,info.DownloadStopReason);
end
if ~complete && p.Results.WarnOnIncomplete
    warning('PocketLab:MemoryDownloadIncomplete', ...
        ['Flash download unconfirmed (reason: %s). Received %d Flash ' ...
         'packets; preserve raw capture and inspect sample count.'], ...
        info.DownloadStopReason,flashCount);
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
