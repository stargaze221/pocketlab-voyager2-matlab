function info = pocketlabMemoryStop(varargin)
%POCKETLABMEMORYSTOP Stop Voyager 2 internal flash recording.
%   info = pocketlabMemoryStop()
%
%   Experimental firmware VP.1.2 operation. Sends stop-recording
%   command 0x6A 0x00, without any erase operation.
%   Optional: "Address" (BLE address; defaults to paired device).

p=inputParser;
addParameter(p,'Address',"",@(v)isstring(v)||ischar(v));
parse(p,varargin{:});
address=string(p.Results.Address);
if strlength(address)==0
    folder=fileparts(mfilename('fullpath'));
    saved=load(fullfile(folder,'pocketlab_pairing.mat'),'pairing');
    address=string(saved.pairing.Address);
end
svc="152FDEA4-28A1-11ED-A261-0242AC120002";
b=ble(address);
tx=characteristic(b,svc,"152FDEA5-28A1-11ED-A261-0242AC120002");
rx=characteristic(b,svc,"152FDEA6-28A1-11ED-A261-0242AC120002");

before=localStatus(tx,rx);
if ~before.Valid
    error('Unrecognized memory status. Stop command was NOT sent.');
end
if ~before.Recording
    info=struct('Address',address,'StopCommandSent',false, ...
        'StopConfirmed',false,'StatusBefore',before, ...
        'StatusAfter',before);
    warning('PocketLab:NotRecording', ...
        'Device does not report recording. No stop command was sent.');
    return
end

write(tx,uint8([106 0]),"withresponse");
pause(0.20);
after=localStatus(tx,rx);
info=struct();
info.Address=address;
info.StopCommandSent=true;
info.StopConfirmed=after.Valid && after.Recorded && ~after.Recording;
info.StatusBefore=before;
info.StatusAfter=after;
fprintf('Memory STOP sent. Saved recording confirmed: %d. Status: %s\n', ...
    info.StopConfirmed,localHex(after.Response));
if ~info.StopConfirmed
    warning('PocketLab:StopUnconfirmed', ...
        'Stop command sent but recorded-data status is unconfirmed.');
end
end

function st=localStatus(tx,rx)
write(tx,uint8(35),"withresponse");
pause(0.10);
write(tx,uint8(35),"withresponse");
pause(0.10);
raw=uint8(read(rx));
st=struct('Response',raw,'Valid',false,'Recording',false, ...
    'Recorded',false,'Flags',NaN);
if numel(raw)>=3 && raw(1)==17
    st.Valid=true;
    st.Flags=double(raw(3));
    st.Recording=bitand(raw(3),uint8(8))~=0;
    st.Recorded=bitand(raw(3),uint8(1))~=0;
end
end

function s=localHex(bytes)
s=strjoin(compose('%02X',uint8(bytes)), ' ');
end
