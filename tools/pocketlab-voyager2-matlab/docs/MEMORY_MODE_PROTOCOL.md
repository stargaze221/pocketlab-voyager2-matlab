# Voyager 2 Memory Mode: experimental MATLAB investigation

**Target:** PocketLab Voyager 2, firmware VP.1.2, hardware VP.2.1.

**Branch:** `experimental/memory-mode-protocol`. Production real-time streaming in `main` is unchanged.

## Evidence from PocketLab Notebook

The user's Edge console and the PocketLab Notebook JS bundle (`voyagerpro` device entry) identify the following commands via the same custom TX/RX characteristics used for streaming:

| Purpose | TX bytes (hex) | Evidence |
|---|---|---|
| Read status | `23` | JS `memoryStatusCommand: [35]`; sends twice and reads RX, status flags at RX byte 3 |
| Enter offline mode | `6C 01` | JS `_offlineModeCommand: [108,1]`; observed |
| Return online | `6C 00` | JS `_onlineModeCommand: [108,0]`; observed |
| Read memory frequency instruction | `29` | JS `_readFrequencyInstructionCommand=41`; observed |
| Read memory chunk length | `27` | JS `_readChunkLengthCommand=39`; observed |
| Download user-space metadata | `4C 81` | JS `_readUserSpaceCommand=[76,129]`; observed |
| Download flash memory data | `4C 76` | JS `downloadFromMemoryCommand=[76,118]`; observed |
| Start memory recording | `6A 01` | JS device entry; **not yet tested through MATLAB** |
| Stop memory recording | `6A 00` | JS device entry; **not yet tested through MATLAB** |
| **Erase flash** | **`4C 97`** | JS `clearMemoryCommand=[76,151]`; **never used by this prototype** |

BLE service: `152FDEA4-28A1-11ED-A261-0242AC120002`

TX characteristic: `152FDEA5-28A1-11ED-A261-0242AC120002`

RX characteristic: `152FDEA6-28A1-11ED-A261-0242AC120002`

### Memory transport structure

- Flash packets start with `0x96` (150 decimal).
- A memory data packet begins with a 1-byte packet ID, 4-byte little-endian sensor selection mask, and 1-byte encoder sample count.
- Non-encoder samples are little-endian IEEE-754 float32 values. No device-side clock value was identified for the standard IMU samples.
- The official JS reconstructs intra-chunk time from the configured frequency instruction, *not* a per-sample hardware timestamp.
- Completion is signaled by packet ID `0x11` (17 decimal) with bit `0x10` set in its third byte.
- Optional user-space metadata starts with `0x95` (149 decimal).
- Example observed: frequency response `14 04 96 00 03 00` gives instruction `0x00960003` = 9830403. The JS interprets the upper 16 bits as 150 ms per chunk and the lower 16 bits as 3 samples, i.e., **nominal** 20 Hz.
- Example observed chunk length: 198 bytes.
- The JS lists `maxNumBLEPayloadBytes=244`. Actual framing must still be confirmed on VP.1.2 hardware.

## MATLAB probe (not yet hardware tested)

Disconnect the PocketLab Notebook web app. For a non-modifying status read:

```matlab
info = pocketlabMemoryProbe("status");
disp(info.MemoryState)
disp(info.StatusResponse)
```

Only after status read succeeds, test raw download:

```matlab
info = pocketlabMemoryProbe("download", ...
    "SaveFile","voyager_memory_raw.mat", ...
    "MaxDuration_s",180);
disp([info.FlashPacketCount info.EndMarkerSeen])
```

The function retains each RX notification and the MATLAB host receive time. It **does not** erase memory, start a new recording, silently convert incoming raw bytes to physical units, or claim verified hardware timing.

Do not run this prototype at the same time as `pocketlabReadMulti` or the official web app. If an incomplete-download warning occurs, preserve the .mat file and check PacketLengths/RawPackets before changing control logic. Record firmware version with any test results.

## Validation checklist

- [ ] Status reply returns the known `Recorded` state for a device with data in memory.
- [ ] Frequency reply and chunk length agree with an official-app reference capture.
- [ ] Flash packet type `0x96` appears and some raw packets are collected.
- [ ] Download-complete marker `0x11` and bit `0x10` is detected.
- [ ] A repeat official-app download still works; no data were erased.
- [ ] Decode channels/masks and compare physical waveforms.
- [ ] Determine what timing is reconstructed versus transmitted by the device.

**Scope:** The sample-time values recovered from the instruction describe requested/nominal sample spacing. They cannot by themselves establish hardware clock drift or sampling jitter.

## Hardware test: VP.1.2 raw memory capture (October 20, 2026)

Observed in MATLAB:
- `pocketlabMemoryProbe("status")`: `11 01 01` → Recorded.
- Raw download: **278 notifications**, including 152 flash packets (`0x96`), 125 full-size all-`FF` packets, one 195-byte all-`FF` packet, and one 3-byte end marker `11 01 11`.
- All 152 flash packets had size **198 bytes**, identical little-endian sensor mask `0x0001FFF0`, and zero encoder samples. Each contained **3 samples × 16 float32 channels** after a 6-byte header, yielding **456 samples**.
- Channel allocation in ascending sensor mask order: acceleration XYZ (3), gyroscope XYZ (3), magnetometer XYZ (3), heading (1), pitch (1), roll (1), quaternion (4). The decoded acceleration Y mean was **1.00373 g**, and all quaternions had norms ~1.
- Chunk response `13 01 C6` establishes 198-byte chunks.
- **Important:** memory-rate response `14 04 FF FF FF FF` is invalid / uninitialized. Treat nominal rate as unknown from this response. The MATLAB probe was patched to reject it.
- User-space packet begins `95 66 06 00 00`, signature `1638`, followed by four uint32 little-endian words: `[1, 4351, 8, 1792543664]`.
- The third user-space word **8** matches frequency index **8 = 20 Hz** in PocketLab Notebook Voyager 2's `M0` frequency table. Nominal duration = 456 / 20 = **22.8 seconds**, last sample nominal t = 22.75 seconds.
- Fourth word `1792543664` corresponds to **2026-10-21 00:47:44 UTC** (local CDT 2026-10-20 19:47:44), consistent with experiment. It is likely a web-app-supplied record start timestamp; the origin is **unverified**.
- The Flash samples have **no individually decoded hardware timestamps**. Relative times are reconstructed at 0.05 s increments based on the app's recorded rate index, without proof of instantaneous hardware sample spacing.
- Standalone offline MATLAB decoder: `pocketlabDecodeMemory.m` (no BLE operations or erase).

Run offline, after pulling the experimental branch:
```matlab
S=load('voyager_memory_raw.mat');
[t,data,meta]=pocketlabDecodeMemory(S.info);
size(data.acceleration)
size(data.quaternion)
meta.NominalFrequencyHz
meta.UserSpaceTimeUTC
plot(t,data.acceleration)
```

**Important caution:** Only the 16-channel `0x0001FFF0` sample mapping was directly verified against this captured .mat file. The decoder can parse other *supported* subsets but those other configurations have not been hardware tested.

## Selective recording and saving (experimental)

The MATLAB prototype now accepts a sensor-group selector on the **recording**
command. The default (no `Sensors` option) is the previously tested full
16-channel layout. Only 20 Hz is currently supported.

```matlab
% After safeguarding/clearing the device's previous recording using app:
startInfo = pocketlabMemoryStart(20, ...
    "Sensors",["acceleration","gyroscope"]);
% Physically move the device; wait the desired duration.
stopInfo = pocketlabMemoryStop();
[t,data,info] = pocketlabMemoryDownload("FilePrefix","my_imu_test");
```

The recording command transmits a bitwise-OR sensor mask from
`pocketlabSensorRegistry`. Valid sensor groups are `acceleration`,
`gyroscope`, `magnetometer`, `heading`, `pitch`, `roll`,
and `quaternion`. Subset recording has **not** yet been verified on the
device: inspect `info.Decoding.ConfigurationMask`, `info.Decoding.SampleCount`
and decoded waveforms before relying on a subset. The actual device mask
is recovered from Flash packets, not inferred from requested sensors.

Optionally filter the **decoded file** after a full-device recording:

```matlab
[t,data,info] = pocketlabMemoryDownload( ...
    "Sensors",["acceleration","gyroscope"],"FilePrefix","imu_only");
```

This second `Sensors` option filters the decoded MAT file only; the raw
capture file is always retained, and does NOT imply the sensor was disabled
during recording. Do not repeatedly download needlessly: a repeated
download was observed to stall after querying the memory chunk size.
The raw-download driver now includes 5-second progress and a 15-second
idle timeout to help diagnose this, but repeatability is still unverified.

The start/stop commands were physically verified with device statuses
`11 01 08` (Recording) and `11 01 01` (Recorded).
A complete 996-sample, 20 Hz *nominal* (~49.8-second) recording was saved
and decoded. No per-sample hardware timestamp was verified.

## MATLAB clear command (experimental, destructive)

`pocketlabMemoryClear.m` uses the PocketLab Notebook's observed
`4C 97` command to delete the **device's** existing recording. It
never modifies previously downloaded MATLAB files. The command is
opt-in, refuses to erase while recording, recognizes only the observed
status bytes (Recorded=`11 01 01`, Empty=`11 01 04`,
Recording=`11 01 08`), and polls for Empty confirmation.

```matlab
% Verify prior experiment has been backed up before this step:
isfile("pocketlab_memory_20261020_205131_raw.mat")
isfile("pocketlab_memory_20261020_205131_decoded.mat")

% After disconnecting the PocketLab web app:
clearInfo = pocketlabMemoryClear("ConfirmErase",true);
assert(clearInfo.EmptyConfirmed, "Memory clear was not confirmed.");

% The next step will test selective logging (unvalidated):
startInfo = pocketlabMemoryStart(20, ...
    "Sensors",["acceleration","gyroscope"]);
```

This MATLAB clear function has **not yet** been tested on hardware.
If the status does not become Empty, do not assume success and do
not attempt recording. The operator must explicitly opt in for every
destructive call; starting/stopping/downloading never auto-clears memory.

## Hardware verification: selected 6-channel recording (October 20, 2026)

- MATLAB `pocketlabMemoryStart(20,"Sensors",["acceleration","gyroscope"])` produced status `11 01 08`; `pocketlabMemoryStop()` produced `11 01 01`.
- Memory frequency reply `14 04 96 00 03 00` gives nominal 20 Hz; chunk length reply `13 01 4E` gives **78 bytes**.
- Flash download completed with **27 BLE notifications**: 26 notifications of **234 bytes**, followed by one of **78 bytes**, and one 3-byte completion notification (28 notifications total).
- Critically, a 234-byte BLE notification concatenates **three 78-byte logical Flash frames**. Each logical frame has a header `96 F0 03 00 00 00`, followed by three 6-channel float32 samples. Frame starts are at offsets 0, 78, and 156 in a 234-byte BLE notification.
- Logical Flash frame count = **26 × 3 + 1 = 79**; sample count = **79 × 3 = 237**; nominal recording duration = **11.85 seconds**, final sample at **11.80 seconds**.
- Header mask `0x000003F0` confirms **acceleration XYZ + gyroscope XYZ** only. No extra sensor channels were recorded in these frames.
- Decoded sample values are all finite; mean acceleration XYZ = approximately [-0.0362, 1.0049, -0.0293] g. Acceleration norm mean is approximately 1.006 g.
- The user-space metadata returned an erased/uninitialized value (0x95 plus 0xFF). The decoder now falls back to the **valid queried frequency instruction** rather than requiring web-app metadata.
- `pocketlabDecodeMemory.m` was corrected to split BLE notifications into `ChunkLength`-sized Flash frames and validate every embedded header and mask.
- `pocketlabMemoryProbe(...).FlashPacketCount` counts *BLE* notifications starting with `0x96`; `pocketlabDecodeMemory(...).meta.FlashPacketCount` counts **logical Flash frames**. `meta.BLEFlashNotificationCount` distinguishes the two.

**Offline regression test using the previously captured raw file (no BLE needed):**
```matlab
repo=gitrepo; pull(repo); clear pocketlabDecodeMemory
S=load("imu_6channel_test_raw.mat");
[t,data,meta]=pocketlabDecodeMemory(S.info);
assert(meta.SampleCount==237)
assert(meta.FlashPacketCount==79)
assert(meta.BLEFlashNotificationCount==27)
assert(meta.ConfigurationMask==uint32(hex2dec('000003F0')))
assert(meta.NominalFrequencyHz==20)
assert(isequal(sort(string(fieldnames(data))),sort(["acceleration";"gyroscope"])))
```

This recording demonstrates correct selective logging at nominal 20 Hz. Device clock accuracy and reliability of back-to-back BLE downloads remain separate, unverified issues.
