# Sensor Unit Validation Guide

This guide is designed for an Experimental Methods laboratory activity using the PocketLab Voyager 2 MATLAB driver.

The goal is **not** to look up the answer first. The goal is to use a known physical reference, collect evidence, and determine which unit interpretation is consistent with the measurements.

## Experimental reasoning pattern

For each sensor, organize your work as:

**Engineering Question → Measurement → Evidence → Analysis / Inference → Engineering Judgment**

For each sensor, document:

1. **Hypothesis** — What unit(s) might the sensor be reporting?
2. **Reference** — What known physical quantity can you compare against?
3. **Experiment** — What motion/orientation/test will you perform?
4. **Evidence** — What plots, calculations, and repeated measurements support your interpretation?
5. **Judgment** — Which unit is most consistent with the evidence, and how confident are you?

Do not rely only on one instantaneous value. Use multiple orientations, motions, or repeated trials.

---

## 1. Accelerometer

Acquire data with:

```matlab
[t,A] = pocketlabRead("acceleration",10,20);
```

where the three columns correspond to the three measured acceleration components.

### Known physical reference

Near Earth's surface,

```text
g ≈ 9.81 m/s^2
```

A sensor may report acceleration in units such as:

```text
g
m/s^2
```

### Suggested experiment

Place the PocketLab at rest in several different orientations.

For each orientation, inspect the three acceleration components and calculate the vector magnitude:

```matlab
amag = sqrt(sum(A.^2,2));
mean_amag = mean(amag)
```

Ask:

- When one axis points approximately upward or downward, what value does that axis approach?
- Does the acceleration magnitude at rest approach approximately 1 or approximately 9.81?
- Does rotating the sensor change the individual components while leaving the magnitude approximately constant?

### Evidence to report

Include at least:

- one time-history plot,
- several stationary orientations,
- the measured acceleration magnitude,
- your unit interpretation,
- one or more reasons the result is not exact.

---

## 2. Gyroscope

Acquire data with:

```matlab
[t,W] = pocketlabRead("gyroscope",10,20);
```

The three columns correspond to angular-rate measurements about three sensor axes.

### Candidate unit interpretations

Angular rate is commonly expressed as:

```text
rad/s
deg/s
```

Do not assume which one is used. Determine it from experiment.

### Known physical reference

A controlled rotation provides a known change in angle.

For example:

```text
90 degrees = pi/2 radians
180 degrees = pi radians
360 degrees = 2*pi radians
```

Angular displacement is related to angular rate by

```text
angle change = integral of angular rate with respect to time
```

In MATLAB, for one measured axis:

```matlab
theta = trapz(t,W(:,axisNumber));
```

or to inspect the accumulated angle over time:

```matlab
theta_history = cumtrapz(t,W(:,axisNumber));
```

### Suggested experiment

1. Keep the sensor still briefly and observe the zero-rate bias.
2. Rotate the sensor approximately 90 degrees about one axis.
3. Repeat the motion several times.
4. Integrate the dominant angular-rate component.

Ask:

- Is the integrated value closer to 90 or to pi/2?
- Does reversing the direction of rotation change the sign?
- How much error is caused by imperfect hand motion, bias, and sampling?

### Evidence to report

Include at least:

- the angular-rate time history,
- the axis used for the test,
- the known approximate rotation angle,
- the integrated sensor output,
- the inferred unit,
- a comparison across repeated trials.

---

## 3. Magnetometer

Acquire data with:

```matlab
[t,B] = pocketlabRead("magnetometer",10,20);
```

The three columns correspond to three magnetic-field components.

### Physical reference

Earth's magnetic field near the surface is typically on the order of **tens of microtesla**.

A magnetic-field sensor may report values in units such as microtesla or another magnetic-field scale. Use the data to determine what interpretation is physically plausible.

### Suggested experiment

Keep the PocketLab in approximately the same location and rotate it slowly through several orientations.

Calculate the measured field magnitude:

```matlab
Bmag = sqrt(sum(B.^2,2));
mean_Bmag = mean(Bmag)
```

Ask:

- Do the individual components change as the sensor rotates?
- Does the vector magnitude remain approximately constant?
- Is the order of magnitude physically reasonable for Earth's magnetic field?
- What happens when the sensor is brought near steel, a magnet, a laptop, or other electronics?

### Important limitation

Indoor magnetic measurements can be strongly distorted by nearby ferromagnetic materials, permanent magnets, electric currents, computers, furniture, and building structure.

A poor match to an ideal Earth-field value does **not** automatically mean the sensor is wrong. It may indicate that the local magnetic environment is not clean.

### Evidence to report

Include at least:

- the three magnetic-field components,
- the field magnitude,
- measurements from several orientations,
- the inferred unit or scale,
- discussion of environmental interference.

---

## Suggested final conclusion format

For each sensor, write a short conclusion using this structure:

> **Claim:** We conclude that the sensor most likely reports ________.  
> **Evidence:** Our strongest evidence is ________.  
> **Comparison:** The measured/reference comparison was ________.  
> **Limitations:** The largest source(s) of uncertainty or error were ________.  
> **Confidence:** We are [highly / moderately / weakly] confident because ________.

The objective is not simply to state a unit. The objective is to show what experimental evidence justifies that conclusion.
