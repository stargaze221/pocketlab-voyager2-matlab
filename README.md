# ME 3310 Experimental Methods — MATLAB Workspace

A MATLAB workspace for **experimental measurement, evidence analysis, and engineering judgment** using the PocketLab Voyager 2. The repository separates instructor-managed BLE/acquisition tools from student-facing laboratory work.

**Start here:** open MATLAB in this repository's root directory, run `startup`, and then launch `pocketlabMemoryApp` for the PocketLab graphical interface.

## Quick start

**First time on a computer**

```matlab
repo = gitclone("https://github.com/stargaze221/pocketlab-voyager2-matlab.git");
cd(repo.WorkingFolder)
startup
pocketlabPair
pocketlabMemoryApp
```

Choose **your own** PocketLab during pairing. **Pair only once on each computer for that device.** The saved `pocketlab_pairing.mat` file is reused automatically in later MATLAB sessions and is intentionally not committed to Git.

**Before each session:** turn on the PocketLab Voyager 2, then run `startup` and `pocketlabMemoryApp`. **Do not run `pocketlabPair` again each time.** Re-pair only if using a different device, if the saved pairing was lost, or if reconnection fails.

**Later sessions / updating the existing checkout**

Turn on the PocketLab's power first. Pairing is already saved on this computer, so skip `pocketlabPair`.

```matlab
repo = gitrepo;
pull(repo);
startup
pocketlabMemoryApp
```

These update commands assume your current repository branch is `main`. `startup` adds the driver folder to the MATLAB path; it does **not** connect to Bluetooth, erase device memory, or automatically launch the GUI. To check the battery without opening the GUI, run `pocketlabBattery`.

> **Bluetooth:** Turn on the PocketLab before acquisition and disconnect the PocketLab Notebook browser application (and any other application using the device) before connecting with MATLAB. `startup` only configures the MATLAB path; the GUI connects when requested. If the saved device cannot reconnect despite being powered on and available, run `pocketlabPair` again.

## PocketLab GUI: two acquisition modes

The GUI header includes a **Check Battery** button. It reads the paired Voyager 2 battery level on demand and shows **Battery: XX%** without starting a recording. The displayed percentage is the last reading, not continuous monitoring. Battery checks are disabled while live streaming, device Memory Mode recording, or a download/other device operation is in progress.

Run:

```matlab
pocketlabMemoryApp
```

| Mode | What happens | Output |
| --- | --- | --- |
| **Real-Time Mode** | PocketLab streams over BLE to MATLAB; the selected signals are plotted as they arrive. | `*_live.mat` saved on the **computer** after the maximum duration or **Stop Live**. No device-memory download is needed. |
| **Memory Mode** | PocketLab records into its **internal Flash memory** without continuous live plotting. Stop, then download to MATLAB to inspect the results. | `*_raw.mat` (BLE capture) and `*_decoded.mat` (reconstructed samples), saved on the **computer**. |

### Real-Time Mode

1. Click **Refresh Status** and select at least two sensor groups. The Acceleration + Gyroscope pairing at nominal 20 Hz is the most thoroughly checked multi-sensor combination.
2. Set **Max duration (s)**, then click **Start Live + Save**.
3. Move the device and observe the plot. Click **Stop Live** to end early, or wait for the maximum duration. The GUI saves a `*_live.mat` file and reports whether Stop Live was detected.

### Memory Mode

1. Click **Refresh Status**. The device must be **Empty** before starting a new Memory Mode recording.
2. Select sensor groups, then click **Start Recording**. The GUI shows an **approximate PC elapsed-time stopwatch** while recording.
3. Click **Stop Recording** and confirm the device changes to **Recorded**.
4. Click **Download & Plot**. The raw and decoded `.mat` files are saved before you decide whether the device recording can be erased. Use **Open MAT (raw/decoded)** to review saved files later.

**Caution — Clear Device:** This action permanently deletes the recording **on the PocketLab**. It asks for confirmation; use it only *after* saving and checking the downloaded files. Clearing the device does not delete files already saved on the PC. Do not attempt live streaming while the device is in Memory Mode recording.

A missing download end marker (`end marker: 0`) means **completion was not confirmed**, even if decoded sensor data and a plot were recovered. Preserve the `*_raw.mat` file. The GUI may stop waiting after a period without new Flash data; timeout is *not* proof of a complete recording.

### Data and time axes

The saved decoded files contain `t`, `data`, and `info`. The time vector `t` is reconstructed using the **nominal sample rate** (typically 20 Hz), not measured hardware sample timestamps. The GUI Memory stopwatch uses the MATLAB computer's elapsed time. They are different estimates and may not match exactly.

The optional GUI **File prefix** controls file names; by default the app creates timestamped names in MATLAB's current folder. Keep output files, especially `*_raw.mat`, for repeatable experimental analysis and to diagnose incomplete transfers. The repository only ignores designated Lab IMU output folders and pairing files by default, so avoid accidentally committing personal measurement captures.

## Command-line acquisition (still supported)

Single-sensor acquisition:

```matlab
[t,A] = pocketlabRead("acceleration",10,20);
[t,W] = pocketlabRead("gyroscope",10,20);
```

Simultaneous acceleration + gyroscope streaming:

```matlab
[t,data,info] = pocketlabReadMulti(["acceleration","gyroscope"],10,20);
A = data.acceleration;
W = data.gyroscope;
```

To examine Memory Mode without the GUI:

```matlab
status = pocketlabMemoryProbe("status");
[t,data,info] = pocketlabMemoryDownload("FilePrefix","trial_01");
```

These commands do not clear device memory. For the complete experimental Memory Mode protocol and limitations, see [the technical investigation](tools/pocketlab-voyager2-matlab/docs/MEMORY_MODE_PROTOCOL.md), which includes historical development notes.

## Lab IMU — experimental reasoning

See [Lab IMU instructions](labs/Lab_IMU/README.md). The student lab focuses on comparing sensor measurements with independent physical references, rather than writing a BLE driver.

From the repository root:

```matlab
startup
run("labs/Lab_IMU/Lab_IMU_Main.m")
run("labs/Lab_IMU/Lab_IMU_Analysis.m")
```

Complete the marked `STUDENT MATLAB CHECKPOINT` in the analysis script before the final analysis run. These lab scripts use the existing command-line acquisition workflow; running `startup` does **not** require the GUI.

## Repository layout

```text
pocketlab-voyager2-matlab/
├── README.md
├── startup.m
├── tools/
│   └── pocketlab-voyager2-matlab/
│       ├── README.md
│       ├── pocketlabPair.m
│       ├── pocketlabRead.m
│       ├── pocketlabReadMulti.m
│       ├── pocketlabMemoryApp.m
│       ├── pocketlabMemoryStart.m
│       ├── pocketlabMemoryStop.m
│       ├── pocketlabMemoryDownload.m
│       ├── pocketlabDecodeMemory.m
│       └── docs/
└── labs/
    └── Lab_IMU/
        ├── README.md
        ├── Lab_IMU_Main.m
        ├── Lab_IMU_Analysis.m
        ├── data/
        ├── figures/
        └── submission/
```

The previous standalone-driver layout is preserved in the `standalone-driver-v1` branch. The workspace's `main` branch is the normal starting point.

## Validation and limitations

- **Checked on Voyager 2 hardware:** BLE pairing and single-sensor acquisition; Acceleration + Gyroscope multi-sensor streaming at nominal 20 Hz; selected Memory Mode sensor combinations, recording, download, and decoded plotting.
- **Still experimental:** additional multi-sensor/channel combinations and sample rates, physical-unit validation for certain sensors, precise sensor synchronization and device-side sample timing, and BLE Flash download completion reliability.
- **Known issue:** on some recordings the complete end marker is not received and the software must report the transfer as **unconfirmed**, even if meaningful data were decoded. Do not equate a good-looking plot with a guaranteed complete download.

This project is intended to help students make defensible conclusions from experimental evidence—including recognizing when the evidence does **not** support a precise claim.
