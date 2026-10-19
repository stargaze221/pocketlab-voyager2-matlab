function test_pocketlabMultiPacket()
%TEST_POCKETLABMULTIPACKET Hardware-free structural tests for candidate parser.
% Run after startup from the repository root:
%   test_pocketlabMultiPacket
%
% Passing does NOT validate the real Voyager 2 multi-sensor wire format.

reg=pocketlabSensorRegistry();
sensors=[reg.acceleration reg.gyroscope];
header=uint8([1 2 3 4 5 6]);

% Two six-channel records, a_x/a_y/a_z then gx/gy/gz in each record.
values=single([0 0 1 10 20 30, 0.1 0.2 0.9 -10 -20 -30]);
payload=typecast(values,'uint8');
packet=[header payload];
[block,ok,reason]=pocketlabDecodeMultiPacket(packet,sensors);
assert(ok,reason);
assert(isequal(size(block),[2 6]));
assert(isequal(block(1,:),values(1:6)));
assert(isequal(block(2,:),values(7:12)));

% Fail closed when payload size does not match configured channels.
[~,ok,reason]=pocketlabDecodeMultiPacket(packet(1:end-1),sensors);
assert(~ok && contains(reason,"length"));

% Fail closed on a single-sensor-looking packet in multi-sensor mode.
accOnlyPacket=[header typecast(single([0 0 1]),'uint8')];
[~,ok,~]=pocketlabDecodeMultiPacket(accOnlyPacket,sensors);
assert(~ok);

% Reject nonfinite IEEE-754 data instead of claiming a measurement.
bad=[header typecast(single([0 0 1 NaN 20 30]),'uint8')];
[~,ok,reason]=pocketlabDecodeMultiPacket(bad,sensors);
assert(~ok && contains(reason,"nonfinite"));

fprintf('PASS: synthetic framing checks (hardware NOT tested).\n');
end
