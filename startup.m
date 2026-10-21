%% ME 3310 Experimental Methods MATLAB Workspace — Startup
% Run from the repository root after cloning or pulling.
% Adds the instructor-managed Voyager 2 tools without opening Bluetooth,
% launching a GUI, changing device state, or erasing recordings.

workspaceRoot = fileparts(mfilename('fullpath'));
driverDir = fullfile(workspaceRoot,"tools","pocketlab-voyager2-matlab");

if ~isfolder(driverDir)
    error("ME 3310 workspace is incomplete: PocketLab driver folder was not found.");
end

% Migrate a local pairing from the earlier standalone-driver layout.
legacyPairing = fullfile(workspaceRoot,"pocketlab_pairing.mat");
driverPairing = fullfile(driverDir,"pocketlab_pairing.mat");

if isfile(legacyPairing) && ~isfile(driverPairing)
    copyfile(legacyPairing,driverPairing);
    fprintf("Migrated existing PocketLab pairing into the tools folder.\n");
end

addpath(driverDir);

fprintf("\nME 3310 Experimental Methods MATLAB Workspace\n");
fprintf("-----------------------------------------\n");
fprintf("Workspace: %s\n",workspaceRoot);
fprintf("PocketLab driver added to MATLAB path.\n");

if isfile(driverPairing)
    fprintf("Pairing: local PocketLab configuration found.\n");
else
    fprintf("Pairing: not found; run pocketlabPair before acquisition.\n");
end

fprintf("\nRECOMMENDED — PocketLab graphical interface:\n");
fprintf("  pocketlabMemoryApp\n");
fprintf("  Real-Time: Start Live + Save / Stop Live (PC .mat file)\n");
fprintf("  Memory:    Start Recording / Stop Recording / Download & Plot\n");
fprintf("  CAUTION:   Clear Device erases PocketLab Flash; back up first.\n");

fprintf("\nOther PocketLab commands:\n");
fprintf("  pocketlabPair                  %% Pair or select your device\n");
fprintf("  pocketlabBattery               %% Check battery\n");
fprintf('  [t,A] = pocketlabRead("acceleration",10,20);\n');
fprintf('  [t,data,info] = pocketlabReadMulti(["acceleration","gyroscope"],10,20);\n');

fprintf("\nLab IMU (run from the repository root):\n");
fprintf('  run("labs/Lab_IMU/Lab_IMU_Main.m")\n');
fprintf('  run("labs/Lab_IMU/Lab_IMU_Analysis.m")\n');

fprintf("\nTiming note: multi-sensor and Memory Mode sample times are nominal.\n");
fprintf("Read README.md for workflows and BLE download limitations.\n\n");

clear driverDir legacyPairing driverPairing
