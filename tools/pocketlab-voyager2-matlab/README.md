# PocketLab Voyager 2 MATLAB Driver

MATLAB BLE interface for the PocketLab Voyager 2.

In the ME3310 workspace, this folder is treated as **instructor-managed infrastructure**. Students should normally call the functions from their lab scripts rather than edit the driver.

Run the workspace `startup.m` first so this folder is added to the MATLAB path.

## Basic use

```matlab
pocketlabPair
pocketlabBattery

[t,A] = pocketlabRead("acceleration",10,20);
[t,W] = pocketlabRead("gyroscope",10,20);
[t,B] = pocketlabRead("magnetometer",10,20);
```

## Current validation status

Acceleration acquisition has been physically verified on multiple computers. Other sensor configurations are available for experimental validation and should not be treated as fully verified until their packet interpretation and engineering units are confirmed.

## Driver utilities

```matlab
pocketlabSensors
PocketLab_demo
PocketLab_test_sensor
PocketLab_all_sensors_demo
```

The local pairing file `pocketlab_pairing.mat` is intentionally ignored by Git.
