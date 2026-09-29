%% PocketLab Voyager 2 - Unit Validation Lab
% Focused student activity for:
%   1) Accelerometer
%   2) Gyroscope
%   3) Magnetometer
%
% Goal:
%   Determine the most plausible engineering units using experimental
%   evidence rather than simply being told the answer.
%
% Before running:
%   pocketlabPair
%
% Suggested reading:
%   SENSOR_UNIT_VALIDATION_GUIDE.md

clear
close all
clc

fprintf('\nPocketLab Voyager 2 - Sensor Unit Validation Lab\n');
fprintf('=================================================\n');
fprintf('Use physical references to infer the sensor units.\n');
fprintf('Do not rely on a single value. Collect evidence.\n\n');

%% 1. Accelerometer
fprintf('\n1. ACCELEROMETER\n');
fprintf('----------------\n');
fprintf('Known reference: g is approximately 9.81 m/s^2 near Earth''s surface.\n');
fprintf('Possible interpretations include g or m/s^2.\n');
fprintf('Suggested test: place the PocketLab at rest in several orientations.\n');
fprintf('Question: is the resting vector magnitude closer to 1 or 9.81?\n\n');

input('Press Enter when ready to collect accelerometer data...','s');

[tA,A,infoA] = pocketlabRead("acceleration",10,20);

Amag = sqrt(sum(A.^2,2));

figure('Name','Accelerometer Unit Validation');
plot(tA,A,'LineWidth',1.1)
hold on
plot(tA,Amag,'k--','LineWidth',1.2)
xlabel('Time [s]')
ylabel('Sensor output')
legend('a_x','a_y','a_z','|a|','Location','best')
title('Accelerometer: Components and Magnitude')
grid on

fprintf('\nAccelerometer summary:\n');
fprintf('Mean magnitude = %.6g\n',mean(Amag));
fprintf('Min magnitude  = %.6g\n',min(Amag));
fprintf('Max magnitude  = %.6g\n',max(Amag));
fprintf('Compare your result with 1 and 9.81.\n');

%% 2. Gyroscope
fprintf('\n\n2. GYROSCOPE\n');
fprintf('-----------\n');
fprintf('Candidate units: rad/s or deg/s.\n');
fprintf('Known reference: 90 deg = pi/2 rad; 180 deg = pi rad.\n');
fprintf('Suggested test: keep the sensor still, then rotate it about one axis\n');
fprintf('by approximately 90 degrees. Repeat if needed.\n');
fprintf('After collection, identify the dominant axis and integrate it.\n\n');

input('Press Enter when ready to collect gyroscope data...','s');

[tW,W,infoW] = pocketlabRead("gyroscope",10,20, ...
    "SuppressExperimentalWarning",true);

rangeW = max(W,[],1)-min(W,[],1);
[~,gyroAxis] = max(rangeW);

theta = cumtrapz(tW,W(:,gyroAxis));
thetaNet = trapz(tW,W(:,gyroAxis));

figure('Name','Gyroscope Unit Validation');
plot(tW,W,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Native decoded angular-rate value')
legend('g_x','g_y','g_z','Location','best')
title('Gyroscope: Angular Rate')
grid on

figure('Name','Gyroscope Integrated Angle');
plot(tW,theta,'LineWidth',1.2)
xlabel('Time [s]')
ylabel('Integrated native value')
title(sprintf('Integrated Gyroscope Output, Axis %d',gyroAxis))
grid on

fprintf('\nGyroscope summary:\n');
fprintf('Automatically selected dominant axis: %d\n',gyroAxis);
fprintf('Integrated value on dominant axis: %.6g\n',thetaNet);
fprintf('For an approximately 90-degree rotation, compare with:\n');
fprintf('  90      if the output behaves like deg/s\n');
fprintf('  pi/2 = %.6g if the output behaves like rad/s\n',pi/2);
fprintf('Account for bias, hand-motion error, and imperfect start/stop timing.\n');

%% 3. Magnetometer
fprintf('\n\n3. MAGNETOMETER\n');
fprintf('--------------\n');
fprintf('Physical reference: Earth''s magnetic field is typically on the order\n');
fprintf('of tens of microtesla near the surface.\n');
fprintf('Suggested test: keep the PocketLab in approximately the same location\n');
fprintf('while slowly rotating it through several orientations.\n');
fprintf('Look for changing components but a roughly consistent vector magnitude.\n\n');

input('Press Enter when ready to collect magnetometer data...','s');

[tB,B,infoB] = pocketlabRead("magnetometer",10,20, ...
    "SuppressExperimentalWarning",true);

Bmag = sqrt(sum(B.^2,2));

figure('Name','Magnetometer Unit Validation');
plot(tB,B,'LineWidth',1.1)
hold on
plot(tB,Bmag,'k--','LineWidth',1.2)
xlabel('Time [s]')
ylabel('Native decoded magnetic-field value')
legend('B_x','B_y','B_z','|B|','Location','best')
title('Magnetometer: Components and Magnitude')
grid on

fprintf('\nMagnetometer summary:\n');
fprintf('Mean magnitude = %.6g\n',mean(Bmag));
fprintf('Min magnitude  = %.6g\n',min(Bmag));
fprintf('Max magnitude  = %.6g\n',max(Bmag));
fprintf('Compare the order of magnitude with a physically reasonable Earth field.\n');
fprintf('Remember: nearby steel, magnets, laptops, currents, and building\n');
fprintf('materials can distort indoor magnetic measurements.\n');

%% Store results
results = struct;
results.acceleration = struct('t',tA,'Y',A,'magnitude',Amag,'info',infoA);
results.gyroscope = struct('t',tW,'Y',W,'axis',gyroAxis, ...
    'integrated',theta,'integratedNet',thetaNet,'info',infoW);
results.magnetometer = struct('t',tB,'Y',B,'magnitude',Bmag,'info',infoB);

fprintf('\n=================================================\n');
fprintf('Unit-validation acquisition complete.\n');
fprintf('All data are stored in the workspace variable: results\n');
fprintf('\nYour job is to make and defend an engineering judgment.\n');
fprintf('Do not report a unit without showing the evidence that supports it.\n');
fprintf('=================================================\n');
