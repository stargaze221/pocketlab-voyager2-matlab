function info = pocketlabMemoryClear(varargin)
%POCKETLABMEMORYCLEAR Clear Voyager 2 internal memory for a new experiment.
%
%   info = pocketlabMemoryClear("ConfirmErase",true)
%
%   DESTRUCTIVE: Removes existing recordings on the DEVICE. Saved MATLAB
%   .mat files are not modified. Back up recordings before calling.
%
%   Safety:
%     * Requires explicit ConfirmErase=true.
%     * Refuses to clear while device reports Recording.
%     * Rejects unknown status replies; never guesses device state.
%     * Reads state after command and confirms Empty (0x11 0x01 0x04).
%     * Does not automatically start another recording.
%
%   Firmware VP.1.2. Erase command 0x4C 0x97 was observed in the official
%   PocketLab Notebook Clear Data workflow; this MATLAB function itself
%   has NOT yet been hardware tested.
%
%   Optional "Address" BLE address (defaults to pocketlabPair setting).

p=inputParser;
addParameter(p,'ConfirmErase',false,@(x)islogical(x)&&isscalar(x));
addParameter(p,'Address',"",@(x)ischar(x)||isstring(x));
parse(p,varargin{:});

if ~p.Results.ConfirmErase
    error(['Clearing DEVICE memory is irreversible. Back up the recorded ' ...
        'data first, then call pocketlabMemoryClear("ConfirmErase",true).']);
end

address=string(p.Results.Address);
if strlength(address)==0
    folder=fileparts(mfilename('fullpath'));
    pairingFile=fullfile(folder,'pocketlab_pairing.mat');
    if ~isfile(pairingFile)
        error('Run pocketlabPair, or provide "Address",address.');
    end
    S=load(pairingFile,'pairing');
    address=string(S.pairing.Address);
end

svc="152FDEA4-28A1-11ED-A261-0242AC120002";
b=ble(address);
tx=characteristic(b,svc,"152FDEA5-28A1-11ED-A261-0242AC120002");
rx=characteristic(b,svc,"152FDEA6-28A1-11ED-A261-0242AC120002");

before=localMemoryStatus(tx,rx);
if ~before.Valid
    error('Unknown memory status (%s); erase command was NOT sent.', ...
        localHex(before.Response));
end
if before.State=="Recording"
    error('Device is recording. Stop recording first; erase command NOT sent.');
end

info=struct();
info.Address=address;
info.StatusBefore=before;
info.EraseCommandSent=false;
info.EmptyConfirmed=before.State=="Empty";
info.StatusAfter=before;

if before.State=="Empty"
    fprintf('Voyager 2 memory already Empty; no erase command sent.\n');
    return
end

% PocketLab Notebook Clear Data: 4C 97. Deletes device-side recording.
write(tx,uint8([76 151]),"withresponse");
info.EraseCommandSent=true;

% Flash erase can take time; use status polling, not a fixed success claim.
for attempt=1:10
    pause(0.4);
    after=localMemoryStatus(tx,rx);
    info.StatusAfter=after;
    if after.Valid && after.State=="Empty"
        info.EmptyConfirmed=true;
        break
    end
end

fprintf('Voyager 2 memory clear sent: %d | Empty confirmed: %d | RX: %s\n', ...
    info.EraseCommandSent,info.EmptyConfirmed, ...
    localHex(info.StatusAfter.Response));

if ~info.EmptyConfirmed
    warning('PocketLab:MemoryClearUnconfirmed', ...
        ['Clear command was sent, but Empty was not confirmed. ' ...
        'Do not start another recording until status is verified.']);
end
end

function result=localMemoryStatus(tx,rx)
write(tx,uint8(35),"withresponse");
pause(0.10);
write(tx,uint8(35),"withresponse");
pause(0.10);
raw=uint8(read(rx));
raw=raw(:).';
result=struct('Response',raw,'Valid',false,'State',"Unknown");
if numel(raw)>=3 && raw(1)==17 && raw(2)==1
    switch double(raw(3))
        case 1
            result.Valid=true;
            result.State="Recorded";
        case 4
            result.Valid=true;
            result.State="Empty";
        case 8
            result.Valid=true;
            result.State="Recording";
    end
end
end

function s=localHex(raw)
if isempty(raw)
    s="";
else
    s=strjoin(compose("%02X",raw)," ");
end
end
