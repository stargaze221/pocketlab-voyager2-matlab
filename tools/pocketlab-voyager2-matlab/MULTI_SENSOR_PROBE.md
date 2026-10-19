# Experimental Voyager 2 simultaneous sensor probe

**Status: experimental / not hardware-validated. Do NOT use in graded ME 3310 data collection yet.**

The existing pocketlabRead.m is unchanged. This separate function tests whether the
Voyager 2 firmware streams several sensor types over one BLE connection when its
configuration flags are combined with bitwise OR.

## Step 1: Open this experimental branch in your local clone

In a terminal at the repository root:

    git fetch origin
    git switch experimental/multi-sensor-ble-probe

In MATLAB, from the repository root:

    startup
    test_pocketlabMultiPacket

The synthetic test checks the candidate decoder only; it does not talk to hardware.
Pair normally first if necessary:

    pocketlabPair

## Step 2: Capture raw packets before trusting any numbers

For an initial 5-second stationary test:

    [t,data,info] = pocketlabReadMulti( ...
        ["acceleration","gyroscope"],5,20, ...
        "DecodePacked",false,"SaveFile","multi_AG_raw.mat");

Inspect packet lengths:

    unique(info.PacketLengths)
    info.PacketCount

Open example packets in hexadecimal:

    for k = 1:min(5,info.PacketCount)
        disp(dec2hex(info.RawPackets{k}))
    end

The assumed packed format (which has NOT been confirmed) predicts:
- Acceleration + gyroscope: 6 header bytes + 12 + 12 = 30 bytes/sample.
- Acceleration + gyroscope + magnetometer: 6 + 12 + 12 + 12 = 42 bytes/sample.

**A different observed length does not mean that simultaneous acquisition
failed.** The firmware may send one sensor per notification, use another
header format, batch samples, or fragment data. In that case update the decoder
from a real raw capture; do not label arbitrary float values as sensor data.

## Step 3: Optional provisional packed-frame attempt

Only after examining the raw packet sizes:

    [t,data,info] = pocketlabReadMulti( ...
        ["acceleration","gyroscope"],10,20, ...
        "SaveFile","multi_AG_candidate.mat");

    data.acceleration
    data.gyroscope
    info.DecodedPacketCount
    info.UndecodedPacketCount

**These returned values are only candidates.** The decoder assumes each
notification contains a six-byte header followed by records of float32
acceleration XYZ, then float32 gyroscope XYZ, in the requested order. That
assumption must be tested against the physical device and independent motion
references. The returned t is an idealized sequence index divided by Fs,
NOT a verified common acquisition timestamp.

## Validation checklist

1. Verify packet lengths and raw bytes with 2 sensors, then 3 sensors.
2. Keep the device at rest: acceleration magnitude should be about 1 g.
3. Rotate about one device axis: test gyro axis, sign, and angular units
   against a physically measured known-angle motion.
4. Compare simultaneous gyro/accel behavior to their corresponding trusted
   single-sensor measurements using pocketlabRead.
5. Verify acquisition timing and whether packet timestamps indicate batches,
   fragments, or distinct per-sensor update times.
6. Only after these steps, convert this prototype to a production decoder.

## Rollback to established classroom version

    git switch main

## Files

- pocketlabReadMulti.m: combined enable command; BLE acquisition; raw capture
- pocketlabDecodeMultiPacket.m: pure, conservative candidate decoder
- test_pocketlabMultiPacket.m: synthetic structural parser tests

The PocketLab's advertised sensor capabilities do not document this
MATLAB-specific raw multi-sensor notification format. The combined bitmask
approach is a hypothesis to be checked using hardware, not a confirmed protocol.
