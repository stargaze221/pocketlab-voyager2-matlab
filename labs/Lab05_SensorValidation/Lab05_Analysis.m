%% ME3310 Lab 05 - Sensor Unit Validation: Analysis
% Basic calculations are provided so the lab can focus on experimental
% evidence and engineering judgment rather than MATLAB syntax.

clearvars
close all
clc

labDir = fileparts(mfilename('fullpath'));
dataDir = fullfile(labDir,"data");
figureDir = fullfile(labDir,"figures");
dataFile = fullfile(dataDir,"Lab05_data.mat");

if ~isfile(dataFile)
    error("Lab05_data.mat was not found. Run Lab05_Main.m first.");
end

load(dataFile,"results");

%% Part A - Accelerometer magnitude
tA = results.accelerometer.t;
A  = results.accelerometer.Y;

Amag = sqrt(sum(A.^2,2));

f1 = figure('Name','Lab05 Accelerometer Evidence');
plot(tA,A,'LineWidth',1.0)
hold on
plot(tA,Amag,'k--','LineWidth',1.4)
xlabel('Time [s]')
ylabel('Sensor output')
legend('x','y','z','magnitude','Location','best')
title('Accelerometer Components and Vector Magnitude')
grid on
exportgraphics(f1,fullfile(figureDir,"11_accelerometer_evidence.png"),'Resolution',150);

fprintf("\nACCELEROMETER EVIDENCE\n");
fprintf("Mean vector magnitude: %.6g\n",mean(Amag));
fprintf("Reference: g = 9.81 m/s^2.\n");
fprintf("Question: Is the measured scale more consistent with g or m/s^2?\n");

%% Part B - Gyroscope bias and integrated angle
tW = results.gyroscope.t;
W  = results.gyroscope.Y;

% The experiment instructed the sensor to remain still for the first ~2 s.
stillIdx = tW <= 2;
gyroBias = mean(W(stillIdx,:),1);
Wcorr = W - gyroBias;

% Choose the axis showing the largest excursion.
gyroRange = max(Wcorr,[],1) - min(Wcorr,[],1);
[~,gyroAxis] = max(gyroRange);

thetaNative = cumtrapz(tW,Wcorr(:,gyroAxis));
thetaNet = thetaNative(end);

f2 = figure('Name','Lab05 Gyroscope Evidence');
plot(tW,Wcorr,'LineWidth',1.0)
xlabel('Time [s]')
ylabel('Bias-corrected sensor output')
legend('x','y','z','Location','best')
title('Gyroscope - Bias-Corrected Angular Rate')
grid on
exportgraphics(f2,fullfile(figureDir,"12_gyroscope_rate_evidence.png"),'Resolution',150);

f3 = figure('Name','Lab05 Gyroscope Integrated Evidence');
plot(tW,thetaNative,'LineWidth',1.4)
xlabel('Time [s]')
ylabel('Integrated native value')
title(sprintf('Integrated Gyroscope Output - Axis %d',gyroAxis))
grid on
exportgraphics(f3,fullfile(figureDir,"13_gyroscope_integrated_evidence.png"),'Resolution',150);

fprintf("\nGYROSCOPE EVIDENCE\n");
fprintf("Estimated zero-rate bias [x y z]: %.6g  %.6g  %.6g\n",gyroBias);
fprintf("Dominant rotation axis: %d\n",gyroAxis);
fprintf("Integrated value: %.6g\n",thetaNet);
fprintf("Known commanded rotation: approximately 90 degrees.\n");
fprintf("Comparison values: 90 deg and pi/2 = %.6g rad.\n",pi/2);
fprintf("Question: Which angular-rate unit is more consistent with the evidence?\n");

%% Part C - Magnetometer vector magnitude
tB = results.magnetometer.t;
B  = results.magnetometer.Y;

Bmag = sqrt(sum(B.^2,2));

f4 = figure('Name','Lab05 Magnetometer Evidence');
plot(tB,B,'LineWidth',1.0)
hold on
plot(tB,Bmag,'k--','LineWidth',1.4)
xlabel('Time [s]')
ylabel('Sensor output')
legend('x','y','z','magnitude','Location','best')
title('Magnetometer Components and Vector Magnitude')
grid on
exportgraphics(f4,fullfile(figureDir,"14_magnetometer_evidence.png"),'Resolution',150);

fprintf("\nMAGNETOMETER EVIDENCE\n");
fprintf("Mean vector magnitude: %.6g\n",mean(Bmag));
fprintf("Std. dev. of magnitude: %.6g\n",std(Bmag));
fprintf("Reference: Earth's field is typically on the order of tens of microtesla.\n");
fprintf("Question: What unit/scale is physically plausible?\n");
fprintf("Also consider indoor magnetic distortion.\n");

%% Save derived analysis
analysis = struct;
analysis.accelerometer.magnitude = Amag;
analysis.accelerometer.meanMagnitude = mean(Amag);
analysis.gyroscope.bias = gyroBias;
analysis.gyroscope.axis = gyroAxis;
analysis.gyroscope.correctedRate = Wcorr;
analysis.gyroscope.integrated = thetaNative;
analysis.gyroscope.integratedNet = thetaNet;
analysis.magnetometer.magnitude = Bmag;
analysis.magnetometer.meanMagnitude = mean(Bmag);
analysis.magnetometer.stdMagnitude = std(Bmag);

save(fullfile(dataDir,"Lab05_analysis.mat"),"analysis");

fprintf("\nAnalysis complete.\n");
fprintf("Use these plots/numbers as evidence, not as automatic conclusions.\n");
fprintf("Your report should state what the evidence actually justifies.\n\n");

clear labDir dataDir figureDir dataFile f1 f2 f3 f4
