%% ME3310 Lab IMU - Guided Analysis
% This script performs most of the analysis for you.
%
% There is ONE MATLAB checkpoint for the student in Part B.
% Replace the NaN on the marked line with the analytical acceleration
% prediction from the Background page.

clearvars
close all
clc

labDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(labDir,"data");
figureDir = fullfile(labDir,"figures");

dataFiles = dir(fullfile(dataDir,"Lab_IMU_data_*.mat"));

if isempty(dataFiles)
    error("No Lab_IMU data file was found. Run Lab_IMU_Main.m first.");
end

[~,latestIdx] = max([dataFiles.datenum]);
dataFile = fullfile(dataFiles(latestIdx).folder,dataFiles(latestIdx).name);

load(dataFile,"results");

if isfield(results,"metadata") && isfield(results.metadata,"runTag")
    runTag = string(results.metadata.runTag);
else
    runTag = string(datetime('now','Format','yyyyMMdd_HHmmss'));
end

fprintf('\nME3310 Lab IMU - Guided Analysis\n');
fprintf('=================================\n');
fprintf('Analyzing:\n  %s\n\n',dataFile);

%% Part A - Accelerometer orientation
fprintf('\nPART A - ACCELEROMETER ORIENTATION\n');
fprintf('----------------------------------\n');

TA = results.accelerometer.orientation.Table;
disp(TA)

fprintf('Interpretation task:\n');
fprintf('  1) Which physical face pair corresponds to each sensor axis?\n');
fprintf('  2) How does the sign change between opposite faces?\n');
fprintf('  3) Is |a| reasonably constant as orientation changes?\n');

fA = figure('Name','Lab IMU - Part A Orientation');
bar(TA{:,{'Mean_ax','Mean_ay','Mean_az'}})
xlabel('Face-down position')
ylabel('Mean accelerometer output')
xticklabels(TA.FaceDown)
legend('a_x','a_y','a_z','Location','best')
title('Part A - Gravity Response for Six Orientations')
grid on
exportgraphics(fA,fullfile(figureDir,"11_accelerometer_orientation_" + runTag + ".png"), ...
    'Resolution',150);

%% Part B - Dynamic accelerometer validation
fprintf('\nPART B - DYNAMIC ACCELEROMETER VALIDATION\n');
fprintf('-----------------------------------------\n');

D = results.accelerometer.dynamic;
A = D.Amplitude_m;
T = D.Period_s;
motionAxis = D.MotionAxis;

aAxis_native = D.Y(:,motionAxis);
aDynamic_native = aAxis_native - mean(aAxis_native);
aMeasured_native = 0.5*(max(aDynamic_native)-min(aDynamic_native));

% If Part A supports the interpretation that the native accelerometer
% output is in g, convert the measured dynamic amplitude to m/s^2.
aMeasured_ms2 = aMeasured_native*9.80665;

fprintf('Reference measurements:\n');
fprintf('  Amplitude A = %.5f m\n',A);
fprintf('  Period T    = %.5f s\n',T);
fprintf('Measured dynamic acceleration amplitude:\n');
fprintf('  %.5f native units\n',aMeasured_native);
fprintf('  %.5f m/s^2 if the Part A g interpretation is used\n',aMeasured_ms2);

% ========================================================================
% STUDENT MATLAB CHECKPOINT - THIS IS THE ONE REQUIRED CODING STEP
%
% From the Background page:
%
%     a_max,ref = (2*pi/T)^2 * A
%
% Replace NaN below with the MATLAB expression for the predicted
% peak acceleration in m/s^2.
% ========================================================================

a_ref = NaN;     % <-- STUDENT: replace NaN with your MATLAB expression

% ========================================================================

if isnan(a_ref)
    fprintf('\nSTUDENT CHECKPOINT NOT COMPLETED.\n');
    fprintf('Edit the line "a_ref = NaN" using the analytical model, then rerun.\n');
    percentDifference = NaN;
else
    percentDifference = 100*abs(aMeasured_ms2-a_ref)/abs(a_ref);

    fprintf('\nDynamic acceleration comparison:\n');
    fprintf('  Reference prediction = %.5f m/s^2\n',a_ref);
    fprintf('  Sensor measurement   = %.5f m/s^2\n',aMeasured_ms2);
    fprintf('  Percent difference   = %.2f %%\n',percentDifference);
end

fB = figure('Name','Lab IMU - Part B Dynamic Acceleration');
plot(D.t,aDynamic_native,'LineWidth',1.2)
xlabel('Time [s]')
ylabel('Mean-removed accelerometer output')
title(sprintf('Part B - Dynamic Acceleration, Sensor Axis %d',motionAxis))
grid on
exportgraphics(fB,fullfile(figureDir,"12_dynamic_acceleration_" + runTag + ".png"), ...
    'Resolution',150);

fprintf('\nEngineering judgment task:\n');
fprintf('Does the agreement support the acceleration measurement?\n');
fprintf('How much disagreement could reasonably come from non-sinusoidal hand motion,\n');
fprintf('amplitude measurement, period measurement, or sensor orientation?\n');

%% Part C - Gyroscope axis identification
fprintf('\nPART C - GYROSCOPE VALIDATION\n');
fprintf('-----------------------------\n');

axisTests = results.gyroscope.axisTests.Data;
physicalNames = results.gyroscope.axisTests.PhysicalAxisNames;

gyroAxisSummary = zeros(3,3);
gyroDominant = zeros(3,1);

for k = 1:3
    Wk = axisTests{k}.Y;
    gyroAxisSummary(k,:) = max(Wk,[],1)-min(Wk,[],1);
    [~,gyroDominant(k)] = max(gyroAxisSummary(k,:));
end

gyroAxisTable = table(physicalNames.',gyroAxisSummary(:,1),gyroAxisSummary(:,2), ...
    gyroAxisSummary(:,3),gyroDominant, ...
    'VariableNames',{'PhysicalRotationAxis','Range_gx','Range_gy','Range_gz','DominantSensorAxis'});

fprintf('Gyroscope axis-identification evidence:\n');
disp(gyroAxisTable)

G = results.gyroscope.validation;
tG = G.t;
W = G.Y;

stillIdx = tG <= 2;
gyroBias = mean(W(stillIdx,:),1);
Wcorr = W-gyroBias;

gyroRange = max(Wcorr,[],1)-min(Wcorr,[],1);
[~,dominantGyroAxis] = max(gyroRange);

thetaNative = cumtrapz(tG,Wcorr(:,dominantGyroAxis));
thetaNetNative = thetaNative(end);

referenceAngle_deg = G.ReferenceAngle_deg;
referenceAngle_rad = deg2rad(referenceAngle_deg);
referenceAvg_deg_s = referenceAngle_deg/G.ReferenceRotationTime_s;
referenceAvg_rad_s = referenceAngle_rad/G.ReferenceRotationTime_s;

fprintf('\nKnown-rotation reference:\n');
fprintf('  Reference angle = %.4f deg = %.6f rad\n',referenceAngle_deg,referenceAngle_rad);
fprintf('  Independent rotation time = %.4f s\n',G.ReferenceRotationTime_s);
fprintf('  Reference average rate = %.4f deg/s = %.6f rad/s\n', ...
    referenceAvg_deg_s,referenceAvg_rad_s);

fprintf('\nGyroscope evidence:\n');
fprintf('  Estimated zero-rate bias [gx gy gz] = [% .5f  % .5f  % .5f]\n',gyroBias);
fprintf('  Dominant sensor axis during validation = %d\n',dominantGyroAxis);
fprintf('  Integrated native value = %.6f\n',thetaNetNative);
fprintf('\nCompare that integrated value with both %.3f deg and %.6f rad.\n', ...
    referenceAngle_deg,referenceAngle_rad);
fprintf('Use the comparison to infer the angular-rate scale/unit.\n');

fG1 = figure('Name','Lab IMU - Part C Gyroscope Rate');
plot(tG,Wcorr,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Bias-corrected gyroscope output')
legend('g_x','g_y','g_z','Location','best')
title('Part C - Bias-Corrected Gyroscope')
grid on
exportgraphics(fG1,fullfile(figureDir,"13_gyroscope_rate_" + runTag + ".png"), ...
    'Resolution',150);

fG2 = figure('Name','Lab IMU - Part C Integrated Gyroscope');
plot(tG,thetaNative,'LineWidth',1.2)
xlabel('Time [s]')
ylabel('Integrated native value')
title(sprintf('Part C - Integrated Gyroscope, Sensor Axis %d',dominantGyroAxis))
grid on
exportgraphics(fG2,fullfile(figureDir,"14_gyroscope_integrated_" + runTag + ".png"), ...
    'Resolution',150);

%% Part D - Magnetometer vs smartphone compass
fprintf('\nPART D - MAGNETOMETER VS SMARTPHONE COMPASS\n');
fprintf('-------------------------------------------\n');

M = results.magnetometer;
phone = M.phoneHeading_deg(:);
Bmean = M.MeanXYZ;
hAxes = M.HorizontalAxesWhenFlat;

fprintf('From Part A, the two approximately horizontal sensor axes are %d and %d.\n', ...
    hAxes(1),hAxes(2));

Bu = Bmean(:,hAxes(1));
Bv = Bmean(:,hAxes(2));

magAngleRaw = atan2d(Bv,Bu);
wrap180 = @(x) mod(x+180,360)-180;
phoneDelta = wrap180(phone-phone(1));
magDelta = wrap180(magAngleRaw-magAngleRaw(1));

headingTable = table((1:numel(phone)).',phone,Bu,Bv,magAngleRaw, ...
    phoneDelta,magDelta,abs(phoneDelta),abs(magDelta), ...
    'VariableNames',{'Position','PhoneHeading_deg','B_horizontal_1', ...
    'B_horizontal_2','MagAngleRaw_deg','PhoneDelta_deg','MagDelta_deg', ...
    'AbsPhoneDelta_deg','AbsMagDelta_deg'});

disp(headingTable)

fprintf('Because axis order/sign can reverse the angle direction, focus first on\n');
fprintf('the MAGNITUDE of the relative heading change.\n');
fprintf('Do approximately 90-deg phone rotations produce approximately 90-deg\n');
fprintf('changes in the horizontal magnetic-field direction?\n');

fM = figure('Name','Lab IMU - Part D Relative Heading');
plot(1:numel(phone),abs(phoneDelta),'o-','LineWidth',1.2)
hold on
plot(1:numel(phone),abs(magDelta),'s-','LineWidth',1.2)
xlabel('Heading position')
ylabel('Magnitude of relative heading change [deg]')
legend('Smartphone reference','Magnetometer','Location','best')
title('Part D - Relative Heading Comparison')
grid on
exportgraphics(fM,fullfile(figureDir,"15_magnetometer_heading_" + runTag + ".png"), ...
    'Resolution',150);

fprintf('\nEngineering judgment task:\n');
fprintf('Discuss agreement with the phone reference and possible magnetic interference\n');
fprintf('from steel, electrical equipment, the phone itself, and the building environment.\n');

%% Save derived analysis
analysis = struct;
analysis.metadata.runTag = runTag;
analysis.accelerometer.orientationTable = TA;
analysis.accelerometer.dynamic.MeasuredNative = aMeasured_native;
analysis.accelerometer.dynamic.Measured_ms2 = aMeasured_ms2;
analysis.accelerometer.dynamic.Reference_ms2 = a_ref;
analysis.accelerometer.dynamic.PercentDifference = percentDifference;
analysis.gyroscope.axisTable = gyroAxisTable;
analysis.gyroscope.bias = gyroBias;
analysis.gyroscope.dominantAxis = dominantGyroAxis;
analysis.gyroscope.integratedNative = thetaNetNative;
analysis.gyroscope.referenceAngle_deg = referenceAngle_deg;
analysis.gyroscope.referenceAngle_rad = referenceAngle_rad;
analysis.magnetometer.headingTable = headingTable;

analysisFile = fullfile(dataDir,"Lab_IMU_analysis_" + runTag + ".mat");
save(analysisFile,"analysis");

fprintf('\n=================================================\n');
fprintf('Analysis complete.\n');
fprintf('Saved analysis:\n  %s\n',analysisFile);
fprintf('\nThe script provides calculations and comparisons, but NOT the final conclusion.\n');
fprintf('Your job is to decide what the evidence actually justifies.\n');
fprintf('=================================================\n\n');
