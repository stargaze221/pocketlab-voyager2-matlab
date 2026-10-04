# Sensor Unit Validation Guide

This guide supports the ME3310 PocketLab Voyager 2 IMU laboratory and is aligned with the current Lab_IMU_Main.m and Lab_IMU_Analysis.m workflow.

The goal is **not** to look up an answer first. The goal is to use an independent physical reference, collect evidence, and decide which interpretation is supported.

## Experimental reasoning pattern

Use the same structure throughout the lab:

**Independent Reference → Expected Behavior / Prediction → Sensor Measurement → Comparison → Engineering Judgment**

The acquisition scripts configure the PocketLab at a nominal **20 Hz** sample rate. The data are transferred to MATLAB over Bluetooth Low Energy (BLE). Therefore, 20 Hz is the configured measurement rate, not the raw Bluetooth radio data rate.

---

## Part A — Accelerometer orientation and scale using gravity

Acquire stationary measurements in six orientations by placing each of the three opposite face pairs downward in turn.

Gravity is the independent reference.

Use the data to determine:

- which physical directions correspond to sensor x, y, and z,
- how the sign changes between opposite faces,
- whether the acceleration-vector magnitude remains approximately constant,
- whether the native acceleration scale is physically consistent with approximately **1 g** at rest.

Near Earth's surface:

    1 g ≈ 9.81 m/s^2

The current MATLAB driver has physically validated the PocketLab accelerometer native output as **g**.

---

## Part B — Dynamic accelerometer validation

Keep Face A down so the PocketLab remains approximately level. Create an approximately straight, horizontal, periodic motion.

Measure the reference independently using peak-to-peak travel L, amplitude A = L/2, elapsed time for several complete cycles, and average period T.

For approximately sinusoidal motion:

    a_max,ref = (2*pi/T)^2 A

This is the **one required student MATLAB coding checkpoint**. In Lab_IMU_Analysis.m, replace the marked NaN with the corresponding MATLAB expression.

A motion near **1 Hz** is a useful target because a 20 Hz acquisition gives approximately 20 samples per cycle. The purpose is not to move as fast as possible, but to produce repeatable motion that the acquisition can resolve clearly.

---

## Part C — Gyroscope axis, sign, bias, and unit inference

First rotate the PocketLab about each of the three physical axes identified in Part A. Determine which gyroscope channel responds most strongly and how the sign changes when rotation direction reverses.

Then perform one quantitative known-angle rotation:

1. Choose a known angle such as 90 or 180 degrees.
2. Rehearse that motion while a partner measures the rotation time.
3. Enter the known angle and practice rotation time when prompted.
4. During the recorded trial, keep the sensor still for about 2 seconds, then reproduce approximately the same known-angle rotation and hold the final orientation.

The initial stationary interval is used to estimate zero-rate bias.

For unit inference, compare the **magnitude** of the integrated native value with both forms of the same known angle:

    90 degrees = pi/2 radians
    180 degrees = pi radians
    360 degrees = 2*pi radians

Use the **signed** integrated value separately to interpret the rotation direction/sign convention.

Common angular-rate units are deg/s and rad/s. The current MATLAB driver intentionally leaves the gyroscope in native decoded units because its engineering-unit interpretation has not yet been physically validated.

---

## Part D — Magnetometer validation with a smartphone compass

Keep Face A down so the PocketLab remains approximately level. Use a smartphone compass as the independent reference instrument.

At four headings distributed around approximately 360 degrees:

1. read and enter the smartphone heading,
2. move the phone away from the PocketLab,
3. keep the PocketLab flat and stationary,
4. record the magnetometer output.

The analysis uses the two horizontal sensor axes inferred from Part A and compares **successive heading changes** rather than absolute north. Because axis order and sign can reverse the direction convention, focus first on the **magnitude** of the heading change.

The analysis also calculates the total three-axis field magnitude:

    Bmag = sqrt(Bx.^2 + By.^2 + Bz.^2);

Earth's magnetic field near the surface is typically on the order of **25–65 microtesla** (about **0.25–0.65 gauss**). Use this only as a scale-plausibility check. The current MATLAB driver does not yet claim a physically validated engineering unit for the PocketLab magnetometer.

Indoor magnetic measurements can also be distorted by steel, magnets, electrical equipment, computers, the smartphone itself, and building structure. A poor match to an ideal Earth-field value does not automatically mean that the sensor is wrong.

---

## Suggested final conclusion format

For each part, organize the conclusion as:

- **Reference:** What independent reference was used?
- **Expected result:** What behavior or value did the reference predict?
- **Measurement:** What did the sensor actually report?
- **Comparison:** How closely did the measurement agree with the reference?
- **Limitations:** What experimental, model, acquisition, or environmental limitation matters?
- **Engineering judgment:** What does the evidence actually justify claiming?

The scripts provide measurements and quantitative comparisons, but deliberately stop before the final engineering conclusion.
