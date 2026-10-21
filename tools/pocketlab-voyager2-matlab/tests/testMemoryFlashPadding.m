function testMemoryFlashPadding()
%TESTMEMORYFLASHPADDING Regression for final all-FF logical Flash frames.
% Run from the driver folder with tests/ on the MATLAB path, or via:
%   run(fullfile('tests','...')) % Not applicable: this is a function
%
% A 210-byte BLE notification can contain 5 x 42-byte logical frames.
% The last notification may contain 1 valid frame + 4 full 0xFF frames.
% This test is synthetic and requires NO hardware or user recordings.

header=uint8([hex2dec('96') 0 224 0 0 0]); % mask 0x0000E000
values=single([1 2 3; 4 5 6; 7 8 9]);
bytes=typecast(reshape(values.',1,[]),'uint8');
[~,~,endianness]=computer;
if endianness~='L', bytes=swapFloat32Endian(bytes); end
frame=[header bytes];
assert(numel(frame)==42);
fullBLE=repmat(frame,1,5);
lastBLE=[frame repmat(uint8(255),1,42*4)];
info=struct('RawPackets',{{fullBLE,lastBLE}}, ...
    'ChunkLength',42,'MemoryRateValid',false, ...
    'UserSpacePacket',uint8([]));
[t,data,meta]=pocketlabDecodeMemory(info,"FrequencyHz",20);
assert(numel(t)==18,'Expected six valid logical frames x 3 samples');
assert(meta.FlashPacketCount==6);
assert(meta.PaddedLogicalFlashFrameCount==4);
assert(meta.ConfigurationMask==uint32(hex2dec('E000')));
assert(all(abs(data.heading-[1;4;7;1;4;7;1;4;7;1;4;7;1;4;7;1;4;7])<1e-6));
assert(all(isfinite(data.pitch)) && all(isfinite(data.roll)));

% A non-FF corrupt header must never be skipped.
corrupt=lastBLE;
corrupt(43)=uint8(0);
info.RawPackets={fullBLE,corrupt};
failed=false;
try
    pocketlabDecodeMemory(info,"FrequencyHz",20);
catch
    failed=true;
end
assert(failed,'Partially corrupt flash headers must be rejected.');
fprintf('PASS: trailing all-FF Flash padding skipped, corrupt headers rejected.\n');
end

function output=swapFloat32Endian(bytes)
output=reshape(flipud(reshape(bytes,4,[])),1,[]);
end
