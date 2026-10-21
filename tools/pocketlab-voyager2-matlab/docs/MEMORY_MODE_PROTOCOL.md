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
