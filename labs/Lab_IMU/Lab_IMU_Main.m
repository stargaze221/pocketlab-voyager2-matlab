%% ME3310 Lab IMU - Guided Data Collection
% Validating sensor measurements using independent references.
%
% Run startup.m from the repository root before this script.
%
% MATLAB handles most acquisition details. Your responsibility is to
% establish the reference carefully, perform the physical experiment,
% and interpret the evidence.

clearvars
close all
clc

if exist("pocketlabRead","file") ~= 2
    error("PocketLab tools are not on the MATLAB path. Run startup.m from the workspace root first.");
end

labDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(labDir,"data");
figureDir = fullfile(labDir,"figures");

if ~isfolder(dataDir), mkdir(dataDir); end
if ~isfolder(figureDir), mkdir(figureDir); end

runTag = string(datetime('now','Format','yyyyMMdd_HHmmss'));

fprintf('\nME3310 Lab IMU - Guided Data Collection\n');
fprintf('========================================\n');
fprintf('Reference -> Prediction -> Measurement -> Comparison -> Judgment\n\n');

batteryLevel = NaN;
try
    batteryLevel = pocketlabBattery;
catch ME
    fprintf('Battery check skipped: %s\n',ME.message);
end

results = struct;
results.metadata.created = datetime('now');
results.metadata.runTag = runTag;
results.metadata.batteryLevel_percent = batteryLevel;

%% Part A - Accelerometer orientation using gravity
fprintf('\nPART A - ACCELEROMETER ORIENTATION USING GRAVITY\n');
fprintf('-------------------------------------------------\n');
fprintf('Temporarily label three pairs of opposite PocketLab faces:\n');
fprintf('  A/B, C/D, and E/F.\n');
fprintf('Place each face DOWN and hold the sensor stationary.\n');
fprintf('Gravity is your independent physical reference.\n\n');

faceLabels = ["A","B","C","D","E","F"];
accelMean = zeros(6,3);
accelMagMean = zeros(6,1);

for k = 1:6
    fprintf('\nPlace Face %s DOWN on a stable surface.\n',faceLabels(k));
    input('Press Enter when the sensor is stationary...','s');

    [~,Y,infoA] = pocketlabRead("acceleration",2.5,20);

    accelMean(k,:) = mean(Y,1);
    accelMagMean(k) = mean(vecnorm(Y,2,2));

    fprintf('Mean [ax ay az] = [% .4f  % .4f  % .4f]\n',accelMean(k,:));
    fprintf('Mean |a|        = %.4f\n',accelMagMean(k));

    if k == 1
        results.accelerometer.info = infoA;
    end
end

[~,dominantAxis] = max(abs(accelMean),[],2);
dominantValue = zeros(6,1);
for k = 1:6
    dominantValue(k) = accelMean(k,dominantAxis(k));
end

partATable = table(faceLabels.',accelMean(:,1),accelMean(:,2),accelMean(:,3), ...
    accelMagMean,dominantAxis,dominantValue, ...
    'VariableNames',{'FaceDown','Mean_ax','Mean_ay','Mean_az', ...
    'MeanMagnitude','DominantAxis','DominantValue'});

fprintf('\nPart A measurement table:\n');
disp(partATable)

results.accelerometer.orientation.FaceLabels = faceLabels;
results.accelerometer.orientation.MeanXYZ = accelMean;
results.accelerometer.orientation.MeanMagnitude = accelMagMean;
results.accelerometer.orientation.DominantAxis = dominantAxis;
results.accelerometer.orientation.DominantValue = dominantValue;
results.accelerometer.orientation.Table = partATable;

verticalAxisWhenFaceADown = dominantAxis(1);
horizontalAxesWhenFaceADown = setdiff(1:3,verticalAxisWhenFaceADown);

fprintf('With Face A down, sensor axis %d is approximately vertical.\n',verticalAxisWhenFaceADown);
fprintf('The other two sensor axes are approximately horizontal.\n');

%% Part B - Dynamic accelerometer validation
fprintf('\nPART B - DYNAMIC ACCELEROMETER VALIDATION\n');
fprintf('-----------------------------------------\n');
fprintf('Keep Face A down so the PocketLab remains approximately level.\n');
fprintf('Move the sensor back and forth approximately along ONE horizontal axis.\n');
fprintf('Measure the motion independently with a ruler/tape and timing.\n\n');

fprintf('Horizontal sensor-axis candidates from Part A: %d and %d.\n', ...
    horizontalAxesWhenFaceADown(1),horizontalAxesWhenFaceADown(2));

motionAxis = input('Which sensor axis will you move approximately along? [1/2/3]: ');
if ~ismember(motionAxis,1:3)
    error('motionAxis must be 1, 2, or 3.');
end

peakToPeak_m = input('Measured peak-to-peak travel L [m]: ');
nCycles = input('Number of complete cycles used for timing: ');
elapsedTime_s = input('Elapsed time for those cycles [s]: ');

validateattributes(peakToPeak_m,{'numeric'},{'scalar','real','positive','finite'});
validateattributes(nCycles,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(elapsedTime_s,{'numeric'},{'scalar','real','positive','finite'});

amplitude_m = peakToPeak_m/2;
period_s = elapsedTime_s/nCycles;

fprintf('\nReference measurements:\n');
fprintf('  Peak-to-peak travel L = %.4f m\n',peakToPeak_m);
fprintf('  Amplitude A           = %.4f m\n',amplitude_m);
fprintf('  Average period T      = %.4f s\n',period_s);
fprintf('\nNow perform several repeatable back-and-forth cycles.\n');

input('Press Enter when ready to record 10 s of motion...','s');

[tBacc,A_dyn,infoBacc] = pocketlabRead("acceleration",10,20);

fB = figure('Name','Lab IMU - Dynamic Accelerometer');
plot(tBacc,A_dyn,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Accelerometer native output')
legend('a_x','a_y','a_z','Location','best')
title('Part B - Dynamic Accelerometer Measurement')
grid on
exportgraphics(fB,fullfile(figureDir,"02_dynamic_accelerometer_" + runTag + ".png"), ...
    'Resolution',150);

results.accelerometer.dynamic.t = tBacc;
results.accelerometer.dynamic.Y = A_dyn;
results.accelerometer.dynamic.info = infoBacc;
results.accelerometer.dynamic.MotionAxis = motionAxis;
results.accelerometer.dynamic.PeakToPeak_m = peakToPeak_m;
results.accelerometer.dynamic.Amplitude_m = amplitude_m;
results.accelerometer.dynamic.CyclesTimed = nCycles;
results.accelerometer.dynamic.ElapsedTime_s = elapsedTime_s;
results.accelerometer.dynamic.Period_s = period_s;

%% Part C - Gyroscope axes and known-angle validation
fprintf('\nPART C - GYROSCOPE AXES AND ROTATION VALIDATION\n');
fprintf('-----------------------------------------------\n');
fprintf('First rotate the PocketLab about each physical axis in turn.\n');
fprintf('Use the face pairs from Part A as the three physical rotation axes.\n\n');

physicalAxisNames = ["A-B","C-D","E-F"];
gyroAxisTests = cell(3,1);

for k = 1:3
    fprintf('\nRotate back and forth mainly about the physical %s axis.\n',physicalAxisNames(k));
    input('Press Enter when ready for a 4 s axis-identification recording...','s');

    [tg,Wg,infoG] = pocketlabRead("gyroscope",4,20, ...
        "SuppressExperimentalWarning",true);

    gyroAxisTests{k} = struct('t',tg,'Y',Wg,'info',infoG);
end

fprintf('\nNow perform one quantitative known-angle rotation.\n');
fprintf('First rehearse the known-angle motion while a partner measures the rotation time.\n');
fprintf('Then reproduce approximately the same motion during the recorded trial.\n');

validationPhysicalAxis = input('Choose physical rotation axis [1=A-B, 2=C-D, 3=E-F]: ');
if ~ismember(validationPhysicalAxis,1:3)
    error('Choose 1, 2, or 3.');
end

referenceAngle_deg = input('Known rotation angle magnitude [deg] (e.g., 90 or 180): ');
referenceRotationTime_s = input('Independent practice rotation time for the same known angle [s]: ');

validateattributes(referenceAngle_deg,{'numeric'},{'scalar','real','positive','finite'});
validateattributes(referenceRotationTime_s,{'numeric'},{'scalar','real','positive','finite'});

fprintf('\nFor the first ~2 s, KEEP THE SENSOR STILL.\n');
fprintf('Then rotate through approximately %.1f deg about the selected axis,\n',referenceAngle_deg);
fprintf('and hold the final orientation still until recording ends.\n');

input('Press Enter when ready for the 10 s validation recording...','s');

[tG,W,infoGval] = pocketlabRead("gyroscope",10,20, ...
    "SuppressExperimentalWarning",true);

fG = figure('Name','Lab IMU - Gyroscope Validation');
plot(tG,W,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Gyroscope native output')
legend('g_x','g_y','g_z','Location','best')
title('Part C - Gyroscope Known-Angle Validation')
grid on
exportgraphics(fG,fullfile(figureDir,"03_gyroscope_validation_" + runTag + ".png"), ...
    'Resolution',150);

results.gyroscope.axisTests.PhysicalAxisNames = physicalAxisNames;
results.gyroscope.axisTests.Data = gyroAxisTests;
results.gyroscope.validation.t = tG;
results.gyroscope.validation.Y = W;
results.gyroscope.validation.info = infoGval;
results.gyroscope.validation.PhysicalAxis = validationPhysicalAxis;
results.gyroscope.validation.ReferenceAngle_deg = referenceAngle_deg;
results.gyroscope.validation.ReferenceRotationTime_s = referenceRotationTime_s;

%% Part D - Magnetometer comparison with smartphone compass
fprintf('\nPART D - MAGNETOMETER VS SMARTPHONE COMPASS\n');
fprintf('-------------------------------------------\n');
fprintf('Keep Face A down so the PocketLab remains approximately level.\n');
fprintf('Use the smartphone compass as the independent reference instrument.\n');
fprintf('After reading the phone heading, MOVE THE PHONE AWAY before recording.\n');
fprintf('Record four headings distributed around approximately 360 degrees.\n\n');

nHeadings = 4;
phoneHeading_deg = zeros(nHeadings,1);
magMean = zeros(nHeadings,3);
magStd = zeros(nHeadings,3);

for k = 1:nHeadings
    fprintf('\nHeading position %d of %d\n',k,nHeadings);
    phoneHeading_deg(k) = input('Smartphone compass heading [deg, 0-360): ');

    fprintf('Move the phone away and keep the PocketLab flat and stationary.\n');
    input('Press Enter to record magnetometer data...','s');

    [~,B,infoM] = pocketlabRead("magnetometer",2.5,20, ...
        "SuppressExperimentalWarning",true);

    magMean(k,:) = mean(B,1);
    magStd(k,:) = std(B,0,1);

    if k == 1
        results.magnetometer.info = infoM;
    end
end

partDTable = table((1:nHeadings).',phoneHeading_deg, ...
    magMean(:,1),magMean(:,2),magMean(:,3), ...
    'VariableNames',{'Position','PhoneHeading_deg','Mean_Bx','Mean_By','Mean_Bz'});

fprintf('\nPart D measurement table:\n');
disp(partDTable)

results.magnetometer.phoneHeading_deg = phoneHeading_deg;
results.magnetometer.MeanXYZ = magMean;
results.magnetometer.StdXYZ = magStd;
results.magnetometer.Table = partDTable;
results.magnetometer.VerticalAxisWhenFlat = verticalAxisWhenFaceADown;
results.magnetometer.HorizontalAxesWhenFlat = horizontalAxesWhenFaceADown;

%% Save all measurements
dataFile = fullfile(dataDir,"Lab_IMU_data_" + runTag + ".mat");
save(dataFile,"results");

fprintf('\n=================================================\n');
fprintf('Data collection complete.\n');
fprintf('Saved data:\n  %s\n',dataFile);
fprintf('Generated figures:\n  %s\n',figureDir);
fprintf('\nNext step:\n');
fprintf('  Open labs/Lab_IMU/Lab_IMU_Analysis.m\n');
fprintf('  Complete the ONE student MATLAB checkpoint in Part B.\n');
fprintf('  Then run the analysis script.\n');
fprintf('=================================================\n\n');

clear labDir dataDir figureDir runTag fB fG
