function [block,ok,reason]=pocketlabDecodeMultiPacket(raw,sensors)
%POCKETLABDECODEMULTIPACKET Candidate parser for Voyager 2 MULTI-SENSOR frames.
%
% Pure function: no Bluetooth dependency. Useful for synthetic tests.
% Hypothesis (NOT yet verified with a real multi-sensor packet):
%     6-byte header followed by one or more fixed-size frames, each frame
%     containing float32 values for sensors in the exact requested order.
%
% The parser is STRICT about length and finite float32 values, but this
% structural check CANNOT establish correct sensor identity or timing.
% Inspect raw packets and validate each channel physically before use.
%
% [block,ok,reason]=pocketlabDecodeMultiPacket(raw,sensors)
%   block: candidate samples x concatenated sensor channels, single
%   ok: true only for packets structurally consistent with hypothesis

block=zeros(0,0,'single');
ok=false;
reason="";

if ~isa(raw,'uint8')
    raw=uint8(raw);
end
raw=raw(:).';
if numel(raw)<=6
    reason="packet too short";
    return
end
if isempty(sensors)
    reason="no sensor descriptors";
    return
end

bytesPerSensor=[sensors.ValueLength];
channels=[sensors.NumChannels];
if any(bytesPerSensor~=4*channels)
    reason="unsupported non-float32 sensor layout";
    return
end

bytesPerFrame=sum(bytesPerSensor);
payload=raw(7:end);
if bytesPerFrame==0 || mod(numel(payload),bytesPerFrame)~=0
    reason="unexpected payload length";
    return
end

nFrames=numel(payload)/bytesPerFrame;
if nFrames<1
    reason="empty payload";
    return
end
values=typecast(payload,'single');
if numel(values)~=nFrames*sum(channels)
    reason="float32 count mismatch";
    return
end

block=reshape(values,sum(channels),[]).';
if any(~isfinite(block(:)))
    block=zeros(0,sum(channels),'single');
    reason="nonfinite candidate value";
    return
end

ok=true;
reason="candidate packed frame; layout unverified";
end
