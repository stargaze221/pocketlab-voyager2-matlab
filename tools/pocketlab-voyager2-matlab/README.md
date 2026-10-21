# PocketLab Voyager 2 MATLAB Driver

BLE acquisition and analysis utilities for the PocketLab Voyager 2, used in the **ME 3310 Experimental Methods** workspace.

This folder is **instructor-managed infrastructure**. Students should normally run `startup` at the repository root and use the supported lab scripts or GUI, rather than editing the driver.

## Recommended: GUI

From the repository root:

```matlab
startup
pocketlabPair          % ONCE on each computer for this PocketLab
pocketlabMemoryApp
```

**On later sessions:** just turn on the PocketLab and run `startup`, then `pocketlabMemoryApp`. The driver automatically reuses the saved pairing; you do **not** need to run `pocketlabPair` every time. Re-pair only when you change devices, lose the saved pairing, or cannot reconnect.

The GUI header includes **Check Battery**, which reads the paired Voyager 2 battery percentage on demand using the standard BLE Battery Level characteristic. It is disabled while recording, streaming, or performing another BLE operation; the displayed value is the last measurement, not continuous monitoring.

The `pocketlabMemoryApp` window offers:

| Feature | How to use | Saved file |
| --- | --- | --- |
| **Real-Time streaming** | Select **one or more** sensor groups, **Start Live + Save**, then **Stop Live** (or let max duration expire). One selected sensor uses `pocketlabRead`; multiple sensors use `pocketlabReadMulti`. | `*_live.mat` |
| **Device Memory Mode** | **Refresh Status**, select sensors, **Start Recording**, **Stop Recording**, **Download & Plot**. | `*_raw.mat`, `*_decoded.mat` |
| **Offline review** | **Open MAT (raw/decoded)** | Reads an existing capture; may save a recovered decoded MAT file. |

Do not run the PocketLab Notebook web app while MATLAB is connected. Do not stream live at the same time as device Memory Mode recording.

**Clear Device permanently erases Flash on the PocketLab.** Save and inspect the raw/decoded PC files before clearing. The GUI asks for confirmation and never erases automatically.

The GUI Memory stopwatch reports *MATLAB PC elapsed time*, not device-verified recording time. The decoded `t` axis is based on nominal sample spacing; it is not measured hardware timestamps.

An absent Flash completion marker (`end marker: 0`) is treated as **unconfirmed download**, even if `*_decoded.mat` is usable. Keep `*_raw.mat` for investigation.

## Existing command-line API

```matlab
pocketlabPair
pocketlabBattery

[t,A] = pocketlabRead("acceleration",10,20);
[t,W] = pocketlabRead("gyroscope",10,20);
[t,B] = pocketlabRead("magnetometer",10,20);

[t,data,info] = pocketlabReadMulti(["acceleration","gyroscope"],10,20);
```

Offline Memory Mode interface (use with care):

```matlab
pocketlabMemoryProbe("status")
pocketlabMemoryStart(20,"Sensors",["acceleration","gyroscope"])
pocketlabMemoryStop
[t,data,info] = pocketlabMemoryDownload("FilePrefix","trial_01");
```

A new Memory Mode recording requires device status **Empty**. Existing recorded data must be backed up before any explicit erase; `pocketlabMemoryStart` does not overwrite device Flash.

## What has been validated?

- Real hardware tests confirm acceleration/gyroscope multi-sensor streaming at **nominal 20 Hz**, and selected device Memory Mode captures with successful decoder output.
- Other combinations, measurement units, packet interpretations, hardware sample timestamps, and synchronization guarantees remain experimental unless independently checked. These **validation-status notes no longer generate repetitive MATLAB warnings** on each ordinary acquisition. Inspect `info.Validated` (single sensor) or `info.DecodingIsVerified` (multi-sensor) when deciding what experimental claims the evidence supports.
- Some Flash transfers return no end marker and instead stop after a no-data-progress timeout. The raw capture is preserved, and such transfers must not be labeled complete.

See the [root README](../../README.md) for the full workspace/lab workflow and [Memory Mode investigation](docs/MEMORY_MODE_PROTOCOL.md) for protocol details and a chronological development record.

Other utilities: `pocketlabSensors`, `PocketLab_demo`, `PocketLab_test_sensor`, `PocketLab_all_sensors_demo`.

Local `pocketlab_pairing.mat` is intentionally ignored by Git.
