%% ME3310 MATLAB Workspace Startup
% Run this script from the repository root after cloning or pulling.

workspaceRoot = fileparts(mfilename('fullpath'));
driverDir = fullfile(workspaceRoot,"tools","pocketlab-voyager2-matlab");

if ~isfolder(driverDir)
    error("ME3310 workspace is incomplete: PocketLab driver folder was not found.");
end

% Migrate pairing from the earlier standalone-driver layout, if present.
legacyPairing = fullfile(workspaceRoot,"pocketlab_pairing.mat");
driverPairing = fullfile(driverDir,"pocketlab_pairing.mat");

if isfile(legacyPairing) && ~isfile(driverPairing)
    copyfile(legacyPairing,driverPairing);
    fprintf("Migrated existing PocketLab pairing into the tools folder.\n");
end

addpath(driverDir);

fprintf("\nME3310 workspace ready.\n");
fprintf("Workspace : %s\n",workspaceRoot);
fprintf("PocketLab driver added to MATLAB path.\n");
fprintf("\nUseful commands:\n");
fprintf("  pocketlabPair\n");
fprintf("  pocketlabBattery\n");
fprintf("  [t,A] = pocketlabRead(\"acceleration\",10,20);\n");
fprintf("\nLab 05:\n");
fprintf("  run(\"labs/Lab05_SensorValidation/Lab05_Main.m\")\n");
fprintf("  run(\"labs/Lab05_SensorValidation/Lab05_Analysis.m\")\n\n");

clear driverDir legacyPairing driverPairing
