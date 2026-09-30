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
│       ├── pocketlabRead.m
│       ├── pocketlabPair.m
│       ├── pocketlabBattery.m
│       └── ...
└── labs/
    └── Lab05_SensorValidation/
        ├── README.md
        ├── Lab05_Main.m
        ├── Lab05_Analysis.m
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

## Returning to the workspace

From the repository root:

```matlab
repo = gitrepo;
pull(repo);
startup
```

Your local PocketLab pairing file and Lab 05 data/figure/submission folders are ignored by Git, so course updates do not replace those local files.

## Lab 05

Read:

```text
labs/Lab05_SensorValidation/README.md
```

Then run:

```matlab
run("labs/Lab05_SensorValidation/Lab05_Main.m")
run("labs/Lab05_SensorValidation/Lab05_Analysis.m")
```

Lab 05 is intentionally structured so that the MATLAB acquisition/analysis mechanics are mostly provided. The student task is to use physical references, measured evidence, and engineering judgment to determine what sensor units are justified by the experiment.
