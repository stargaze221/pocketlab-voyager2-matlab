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
