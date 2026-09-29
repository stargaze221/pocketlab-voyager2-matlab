# PocketLab Voyager 2 MATLAB Driver

Direct BLE acquisition from a PocketLab Voyager 2 into MATLAB.

This repository is intended for experimental-methods teaching and simple MATLAB-based sensor acquisition. The driver pairs a computer with one Voyager 2, stores its BLE address locally, and exposes a simple sensor-reading interface.

## Requirements

- MATLAB with Bluetooth Low Energy support
- A PocketLab Voyager 2
- Bluetooth enabled on the computer

## Quick start

Clone the repository from MATLAB:

```matlab
repo = gitclone("https://github.com/stargaze221/pocketlab-voyager2-matlab.git");
cd(repo.WorkingFolder)
```

Pair your computer with one PocketLab:

```matlab
pocketlabPair
```

Then acquire the physically validated accelerometer stream:

```matlab
[t,A] = pocketlabRead("acceleration",10,20);

plot(t,A)
xlabel("Time [s]")
ylabel("Acceleration [g]")
legend("a_x","a_y","a_z")
grid on
```

The convenience wrapper also works:

```matlab
[t,A] = pocketlabAccel(10,20);
```

## Updating

After cloning once, update the local driver from MATLAB with:

```matlab
repo = gitrepo;
pull(repo);
```

The local pairing file is excluded from Git, so updating the repository does not remove the computer's saved PocketLab pairing.

## Sensor list

Run:

```matlab
pocketlabSensors
```

The driver currently contains Voyager 2 configuration entries for:

- acceleration
- gyroscope
- magnetometer
- heading / pitch / roll
- quaternion
- rangefinder
- rangefinder-derived displacement / velocity / acceleration
- external sensor
- temperature
- pressure
- humidity
- altitude
- dew point
- heat index
- UV light
- ambient light
- IR light

**Validation status:** only acceleration has been physically validated with this MATLAB driver so far. Other sensor entries use configuration values from PocketLab's public Voyager 2 software and are intentionally marked experimental until checked on hardware.

Recommended next hardware tests:

```matlab
[t,W,info] = pocketlabRead("gyroscope",5,20);
[t,R,info] = pocketlabRead("rangefinder",5,20);
[t,T,info] = pocketlabRead("temperature",10,1);
[t,P,info] = pocketlabRead("pressure",10,1);
```

`PocketLab_test_sensor.m` is included to display decoded values and raw packet bytes during validation.

## Supported sampling rates

```text
1/60, 1/30, 1/15, 1/10, 1/5, 1, 5, 10, 20, 25, 50, 250 Hz
```

20 Hz acceleration has been physically tested.

## Pairing

`pocketlabPair` scans nearby devices whose advertised name begins with `PL`, displays them in RSSI order, and stores the selected BLE address in:

```text
pocketlab_pairing.mat
```

That file is intentionally excluded from Git because it is specific to one computer/sensor pairing.

To switch sensors:

```matlab
pocketlabForget
pocketlabPair
```

## Notes

This is an independent MATLAB interface developed for teaching and experimental use. It is not an official PocketLab product.


## Interactive all-sensor demo

After pairing, run:

```matlab
PocketLab_all_sensors_demo
```

The script steps through the available onboard sensors one at a time, prompts for the appropriate physical interaction, prints decoded values and the first raw BLE packet, plots successful streams, and stores all results in a `results` structure. Acceleration is currently validated; the remaining streams should be treated as experimental until their decoding and engineering units are confirmed.


## Unit-validation lab

For a structured Experimental Methods activity focused on accelerometer, gyroscope, and magnetometer unit inference, see:

```text
SENSOR_UNIT_VALIDATION_GUIDE.md
```

and run:

```matlab
PocketLab_unit_validation_lab
```

The activity deliberately provides physical references and candidate interpretations without simply giving students the answer. Students are expected to justify their conclusions using measured evidence.
