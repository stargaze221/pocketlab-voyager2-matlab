# Lab IMU — Sensor Unit Validation from Experimental Evidence

## Engineering question

**Can you determine what a sensor is actually reporting, including its engineering unit, using experimental evidence rather than simply accepting a label?**

This lab focuses on three PocketLab Voyager 2 sensors:

1. Accelerometer
2. Gyroscope
3. Magnetometer

The MATLAB acquisition and basic analysis structure are provided. Your responsibility is to design/execute the physical test carefully, interpret the evidence, and defend the unit that the evidence supports.

## Before the lab

From the workspace root:

```matlab
startup
pocketlabPair
pocketlabBattery
```

Then read `SENSOR_UNIT_VALIDATION_GUIDE.md`.

## Physical references you may use

### Accelerometer

Near Earth's surface,

```text
g ≈ 9.81 m/s^2
```

A measured acceleration could therefore plausibly be expressed in units such as `g` or `m/s^2`.

### Gyroscope

Angular rate is commonly expressed in `rad/s` or `deg/s`.

Useful angular references:

```text
90 deg  = pi/2 rad
180 deg = pi rad
360 deg = 2*pi rad
```

Angular displacement is obtained by integrating angular rate over time.

### Magnetometer

Earth's magnetic field near the surface is typically on the order of **tens of microtesla**. Indoor measurements may be distorted by steel, magnets, electrical current, computers, furniture, and building structure.

## Workflow

First collect the three datasets:

```matlab
run("labs/Lab_IMU/Lab_IMU_Main.m")
```

Then run the provided analysis:

```matlab
run("labs/Lab_IMU/Lab_IMU_Analysis.m")
```

The scripts save your measured data under `data/` and generated figures under `figures/`.

## Required experimental evidence

For each sensor, organize your conclusion as:

**Claim → Test → Evidence → Analysis / Inference → Engineering Judgment**

For each sensor, answer:

- What unit or scale do you claim the sensor reports?
- What known physical reference did you use?
- What experimental observation supports the claim?
- What quantitative comparison supports the claim?
- What are the important error/uncertainty sources?
- How strongly does the evidence justify the conclusion?

Looking at source code, documentation, or an online answer is **not experimental evidence**. Such information may be used later as an external cross-check, but your lab conclusion must be supported by your own measured data.
