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
    fprintf("PocketLab pairing: saved on this computer (no re-pairing needed).\n");
else
    fprintf("PocketLab pairing: not found. Run pocketlabPair ONCE on this computer.\n");
end

fprintf("\nBefore EVERY session: turn on your PocketLab Voyager 2.\n");
fprintf("Pairing is normally needed only once per computer/device.\n");
fprintf("Run pocketlabPair again only if you switch sensors,\n");
fprintf("the saved pairing is missing, or reconnection fails.\n");
fprintf("Close the PocketLab browser app before connecting with MATLAB.\n");

fprintf("\nRECOMMENDED — PocketLab graphical interface:\n");
fprintf("  pocketlabMemoryApp\n");
fprintf("  Real-Time: Start Live + Save / Stop Live (PC .mat file)\n");
fprintf("  Memory:    Start Recording / Stop Recording / Download & Plot\n");
fprintf("  CAUTION:   Clear Device erases PocketLab Flash; back up first.\n");

fprintf("\nOther PocketLab commands:\n");
fprintf("  pocketlabPair                  %% First setup only (or change device)\n");
fprintf("  pocketlabBattery               %% Check battery\n");
fprintf('  [t,A] = pocketlabRead("acceleration",10,20);\n');
fprintf('  [t,data,info] = pocketlabReadMulti(["acceleration","gyroscope"],10,20);\n');

fprintf("\nLab IMU (run from the repository root):\n");
fprintf('  run("labs/Lab_IMU/Lab_IMU_Main.m")\n');
fprintf('  run("labs/Lab_IMU/Lab_IMU_Analysis.m")\n');

fprintf("\nTiming note: multi-sensor and Memory Mode sample times are nominal.\n");
fprintf("Read README.md for workflows and BLE download limitations.\n\n");

clear driverDir legacyPairing driverPairing
