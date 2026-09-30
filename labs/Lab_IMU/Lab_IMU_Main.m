%% ME3310 Lab IMU - Sensor Unit Validation: Data Collection
% Run workspace startup.m before this script.
%
% This script performs the acquisition. Your main task is to execute the
% physical experiment carefully and later interpret the evidence.

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

% One timestamp identifies all files from this acquisition run.
runTag = string(datetime('now','Format','yyyyMMdd_HHmmss'));

fprintf("\nME3310 Lab IMU - Sensor Unit Validation\n");
fprintf("=======================================\n");

batteryLevel = NaN;
try
    batteryLevel = pocketlabBattery;
catch ME
    fprintf("Battery check skipped: %s\n",ME.message);
end

%% Part A - Accelerometer
fprintf("\nPART A - ACCELEROMETER\n");
fprintf("----------------------\n");
fprintf("Known reference: g is approximately 9.81 m/s^2.\n");
fprintf("During the 10 s recording, hold the sensor still in several orientations.\n");
fprintf("Try to place different sensor axes approximately vertical.\n");
input("Press Enter when ready...","s");

[tA,A] = pocketlabRead("acceleration",10,20);

fA = figure('Name','Lab_IMU Raw Accelerometer');
plot(tA,A,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Raw sensor output')
legend('x','y','z','Location','best')
title('Accelerometer - Raw Components')
grid on
exportgraphics(fA,fullfile(figureDir,"01_accelerometer_raw_" + runTag + ".png"),'Resolution',150);

%% Part B - Gyroscope
fprintf("\nPART B - GYROSCOPE\n");
fprintf("------------------\n");
fprintf("Candidate units include rad/s and deg/s.\n");
fprintf("For the first ~2 s, keep the sensor completely still.\n");
fprintf("Then rotate it approximately +90 degrees about ONE axis and hold it still again.\n");
input("Press Enter when ready...","s");

[tW,W] = pocketlabRead("gyroscope",10,20, ...
    "SuppressExperimentalWarning",true);

fW = figure('Name','Lab_IMU Raw Gyroscope');
plot(tW,W,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Raw sensor output')
legend('x','y','z','Location','best')
title('Gyroscope - Raw Components')
grid on
exportgraphics(fW,fullfile(figureDir,"02_gyroscope_raw_" + runTag + ".png"),'Resolution',150);

%% Part C - Magnetometer
fprintf("\nPART C - MAGNETOMETER\n");
fprintf("---------------------\n");
fprintf("Keep the sensor in approximately the same location.\n");
fprintf("Slowly rotate it through several orientations during the 10 s recording.\n");
fprintf("Avoid deliberately placing it near a magnet or large steel object for this first test.\n");
input("Press Enter when ready...","s");

[tB,B] = pocketlabRead("magnetometer",10,20, ...
    "SuppressExperimentalWarning",true);

fB = figure('Name','Lab_IMU Raw Magnetometer');
plot(tB,B,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Raw sensor output')
legend('x','y','z','Location','best')
title('Magnetometer - Raw Components')
grid on
exportgraphics(fB,fullfile(figureDir,"03_magnetometer_raw_" + runTag + ".png"),'Resolution',150);

%% Save measurements
results = struct;
results.metadata.created = datetime('now');
results.metadata.runTag = runTag;
results.metadata.batteryLevel_percent = batteryLevel;
results.accelerometer.t = tA;
results.accelerometer.Y = A;
results.gyroscope.t = tW;
results.gyroscope.Y = W;
results.magnetometer.t = tB;
results.magnetometer.Y = B;

dataFile = fullfile(dataDir,"Lab_IMU_data_" + runTag + ".mat");
save(dataFile,"results");

fprintf("\nData collection complete.\n");
fprintf("Saved data: %s\n",dataFile);
fprintf("Raw figures: %s\n",figureDir);
fprintf("\nNext run:\n");
fprintf('  run("labs/Lab_IMU/Lab_IMU_Analysis.m")\n\n');

clear labDir dataDir figureDir fA fW fB tA tW tB A W B dataFile runTag
