# Lab IMU — Validating Sensor Measurements Using Independent References

## Engineering question

**How can we determine whether a sensor output is physically meaningful and trustworthy?**

The main objective is not MATLAB programming and not simply learning how to operate an IMU. The lab uses the same experimental reasoning pattern in four different sensor tests:

**Independent Reference → Expected Behavior / Prediction → Sensor Measurement → Quantitative Comparison → Engineering Judgment**

MATLAB handles the Bluetooth acquisition and most of the calculations. Students establish the physical reference, perform the experiment, inspect the evidence, and decide what conclusions the evidence justifies.

## Part A — Accelerometer orientation using gravity

Temporarily label the six PocketLab faces as three opposite pairs: A/B, C/D, and E/F. Place each face downward in turn while the sensor is stationary.

Use gravity as the independent reference to determine:

- which physical directions correspond to sensor x, y, and z axes,
- how the sign changes between opposite orientations,
- whether the acceleration-vector magnitude remains approximately constant,
- whether the native acceleration scale is physically consistent with approximately 1 g at rest.

## Part B — Dynamic accelerometer validation

Keep Face A down so the PocketLab remains approximately level. Create an approximately straight, horizontal, periodic motion.

Measure the reference independently using:

- peak-to-peak travel L,
- amplitude A = L/2,
- elapsed time for several complete cycles,
- average period T.

For an approximately sinusoidal motion, the predicted peak acceleration is

    a_max,ref = (2*pi/T)^2 A

This is the **one required student MATLAB coding checkpoint**. In `Lab_IMU_Analysis.m`, replace the marked `NaN` with the MATLAB expression for this analytical prediction.

Everything else in the analysis is provided so that the focus remains on experimental validation rather than syntax.

The lab configures the PocketLab at a nominal 20 Hz sample rate. A motion near 1 Hz is a useful target because it provides roughly 20 samples per cycle and is comfortably below the 10 Hz Nyquist frequency.

## Part C — Gyroscope axis and known-angle validation

First rotate the PocketLab about each of the three physical axes defined by the face pairs from Part A. Determine which gyroscope channel responds most strongly to each physical rotation.

Then perform one known-angle rotation, such as 90 or 180 degrees. Establish the angle independently. Before the recorded trial, rehearse the same known-angle motion while a partner measures the rotation time, then reproduce approximately the same motion during the 10-second recording.

The analysis script automatically:

- estimates zero-rate bias from the initial stationary interval,
- identifies the dominant gyroscope channel,
- integrates angular rate over time,
- reports the signed integrated native value and its magnitude,
- reports the reference angle in both degrees and radians.

For unit inference, students compare the **magnitude** of the integrated native value with the known angle in degrees and radians. The sign is interpreted separately as evidence about rotation direction. The script intentionally does **not** state the final unit interpretation.

## Part D — Magnetometer comparison with a smartphone compass

Keep Face A down so the PocketLab remains approximately level. Use a smartphone compass as the independent reference instrument.

At each heading:

1. read the smartphone heading,
2. move the phone away from the PocketLab,
3. record the stationary magnetometer output.

The analysis uses the two horizontal sensor axes inferred from Part A and compares **successive heading changes** rather than absolute compass heading. This reduces sensitivity to arbitrary heading offsets and 0/360-degree wrapping.

Because axis order and sign can reverse the direction convention, the introductory comparison emphasizes the **magnitude** of each heading change.

The analysis also computes the three-axis magnetic-field magnitude in native decoded units as a secondary scale-plausibility check. Earth's surface field is typically on the order of tens of microtesla, but the current MATLAB driver does not yet claim a validated engineering unit for the magnetometer, so this is supporting evidence rather than an exact calibration.

## Workflow

From the repository root:

    startup
    pocketlabBattery

If pairing is needed:

    pocketlabPair

Collect the four experiments:

    run("labs/Lab_IMU/Lab_IMU_Main.m")

Then open `labs/Lab_IMU/Lab_IMU_Analysis.m`, find the section labeled `STUDENT MATLAB CHECKPOINT`, replace the single `NaN` assignment, and run:

    run("labs/Lab_IMU/Lab_IMU_Analysis.m")

## Output files

Each experiment run receives a timestamp in the form `yyyyMMdd_HHmmss`. Data and figures from the same run share the same timestamp and are not overwritten by later trials.

## What students should conclude

For every part, the final response should identify:

- **Reference:** What independent reference was used?
- **Expected result:** What behavior or value did the reference predict?
- **Measurement:** What did the sensor actually report?
- **Comparison:** How closely did the measurement agree with the reference?
- **Limitations:** What experimental error, model error, or environmental effect matters?
- **Engineering judgment:** What does the evidence actually justify claiming?

The scripts provide measurements and quantitative comparisons, but deliberately stop before the final engineering conclusion.