# ME3310 Experimental Methods MATLAB Workspace

This repository now uses a **workspace layout** so that course/lab files are separated from instructor-managed measurement tools.

The previous standalone PocketLab-driver layout is preserved on the branch:

```text
standalone-driver-v1
```

## Workspace layout

```text
repo/
├── startup.m
├── tools/
│   └── pocketlab-voyager2-matlab/
│       ├── pocketlabReadMulti.m\n│       ├── pocketlabDecodeMultiPacket.m\n│       ├── pocketlabRead.m
│       ├── pocketlabPair.m
│       ├── pocketlabBattery.m
│       └── ...
└── labs/
    └── Lab_IMU/
        ├── README.md
        ├── Lab_IMU_Main.m
        ├── Lab_IMU_Analysis.m
        ├── SENSOR_UNIT_VALIDATION_GUIDE.md
        ├── data/
        ├── figures/
        └── submission/
```

The idea is similar to a ROS workspace: **tools are managed infrastructure; labs are the student working area.**

## First-time setup

Clone the repository:

```matlab
repo = gitclone("https://github.com/stargaze221/pocketlab-voyager2-matlab.git");
cd(repo.WorkingFolder)
startup
```

Pair a PocketLab once on each computer:

```matlab
pocketlabPair
```

Check the battery if desired:

```matlab
pocketlabBattery
```

## PocketLab acquisition

For one sensor, use the established single-sensor interface:

```matlab
[t,A] = pocketlabRead("acceleration",10,20);
[t,W] = pocketlabRead("gyroscope",10,20);
```

For acceleration and gyroscope acquired together in one BLE stream:

```matlab
[t,data,info] = pocketlabReadMulti(["acceleration","gyroscope"],10,20);
A = data.acceleration;   % N-by-3, acceleration (g)
W = data.gyroscope;      % N-by-3, angular velocity (deg/s)
```

The combined-stream format was tested on a physical Voyager 2 at 20 Hz. Observed 102-byte packets contain a 6-byte header followed by four six-channel float32 samples. Stationary tests produced acceleration near 1 g and gyroscope values consistent with independent single-sensor acquisition. Motion tests showed corresponding acceleration and gyroscope changes.

**Limitations:** This remains an experimental acquisition interface. The returned `t` vector uses nominal intervals `(0:N-1)/Fs`, not device-verified per-sample timestamps. Precise cross-sensor synchronization, packet loss behavior, other sensor combinations, and other sampling rates have not been established. Retain `info.RawPackets` for diagnostics and do not infer sub-sample synchronization precision from visual plot alignment. The existing `pocketlabRead` remains available.

## Returning to the workspace

From the repository root:

```matlab
repo = gitrepo;
pull(repo);
startup
```

Your local PocketLab pairing file and Lab IMU data/figure/submission folders are ignored by Git, so course updates do not replace those local files.

## Lab IMU

Read:

```text
labs/Lab_IMU/README.md
```

Then run:

```matlab
run("labs/Lab_IMU/Lab_IMU_Main.m")
run("labs/Lab_IMU/Lab_IMU_Analysis.m")
```

Lab IMU is intentionally structured so that the MATLAB acquisition/analysis mechanics are mostly provided. The student task is to use physical references, measured evidence, and engineering judgment to determine what sensor units are justified by the experiment.
