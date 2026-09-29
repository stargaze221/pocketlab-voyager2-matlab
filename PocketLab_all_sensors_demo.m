%% PocketLab Voyager 2 - All Sensor Demo / Validation Script
% This script tests the Voyager 2 sensors one at a time.
%
% Before running:
%   1) Clone/pull the repository.
%   2) Run pocketlabPair once.
%   3) Turn off the PocketLab web app or other BLE apps.
%
% Important:
%   - Acceleration is physically validated.
%   - The other sensors are EXPERIMENTAL in this MATLAB driver until
%     their packet structure and engineering units are confirmed.
%   - This demo intentionally reads ONE sensor at a time.
%
% During each test, follow the prompt and interact with the sensor.
% Type:
%   Enter = run the test
%   s     = skip this sensor
%   q     = quit the demo

clear
close all
clc

fprintf('\nPocketLab Voyager 2 - All Sensor Demo\n');
fprintf('======================================\n');
fprintf('Acceleration is validated. Other sensors are experimental.\n');
fprintf('Each sensor will be tested one at a time.\n\n');

%% Test configuration
tests = struct( ...
    'key', { ...
        "acceleration", ...
        "gyroscope", ...
        "magnetometer", ...
        "heading", ...
        "pitch", ...
        "roll", ...
        "quaternion", ...
        "rangefinder", ...
        "temperature", ...
        "pressure", ...
        "humidity", ...
        "altitude", ...
        "dewpoint", ...
        "heatindex", ...
        "uvlight", ...
        "ambientlight", ...
        "irlight"}, ...
    'Fs', { ...
        20,20,20,10,10,10,10,20, ...
        1,1,1,1,1,1,1,5,5}, ...
    'duration', { ...
        5,5,5,5,5,5,5,5, ...
        8,8,8,8,8,8,8,5,5}, ...
    'instruction', { ...
        "Move and shake the PocketLab along several axes.", ...
        "Rotate the PocketLab about several axes.", ...
        "Rotate the PocketLab and move it near/away from metal objects.", ...
        "Rotate the PocketLab slowly in the horizontal plane.", ...
        "Tilt the PocketLab forward and backward.", ...
        "Roll the PocketLab left and right.", ...
        "Rotate and tilt the PocketLab through several orientations.", ...
        "Move your hand or a flat object toward and away from the rangefinder.", ...
        "Hold the PocketLab in your hand to warm it slightly.", ...
        "Keep the PocketLab still; this first test checks that pressure data are received.", ...
        "Hold the PocketLab near your hand/breath, then move it away.", ...
        "Keep the PocketLab still; this first test checks that altitude data are received.", ...
        "Hold the PocketLab near your hand/breath, then move it away.", ...
        "Hold the PocketLab near your hand/breath, then move it away.", ...
        "Expose the PocketLab to different amounts of light if possible.", ...
        "Cover and uncover the ambient-light sensor.", ...
        "Cover/uncover the sensor and vary nearby IR/light sources if available."} ...
    );

%% Results container
results = struct;

for k = 1:numel(tests)

    key = tests(k).key;
    Fs = tests(k).Fs;
    duration = tests(k).duration;

    fprintf('\n------------------------------------------------------------\n');
    fprintf('Sensor %d of %d: %s\n',k,numel(tests),upper(key));
    fprintf('Sampling rate: %g Hz | Duration: %g s\n',Fs,duration);
    fprintf('%s\n',tests(k).instruction);

    response = input('Press Enter to run, s to skip, q to quit: ','s');

    if strcmpi(strtrim(response),'q')
        fprintf('\nDemo stopped by user.\n');
        break
    elseif strcmpi(strtrim(response),'s')
        fprintf('Skipped %s.\n',key);
        continue
    end

    try
        [t,Y,info] = pocketlabRead(key,duration,Fs, ...
            "SuppressExperimentalWarning",true);

        % Save everything in the workspace.
        results.(key).t = t;
        results.(key).Y = Y;
        results.(key).info = info;

        fprintf('\nDecoded data size: %d x %d\n',size(Y,1),size(Y,2));
        fprintf('Unit/status: %s',info.Unit);
        if info.Validated
            fprintf(' (validated)\n');
        else
            fprintf(' (experimental)\n');
        end

        if ~isempty(Y)
            fprintf('\nFirst decoded values:\n');
            disp(Y(1:min(8,end),:));

            fprintf('Column min/max:\n');
            disp(table(min(Y,[],1).',max(Y,[],1).', ...
                'VariableNames',{'Min','Max'}));
        else
            fprintf('No decoded samples were returned.\n');
        end

        if ~isempty(info.RawPackets)
            raw = info.RawPackets{1};
            fprintf('\nFirst raw packet: %d bytes\n',numel(raw));
            fprintf('Hex bytes:\n');
            disp(join(string(dec2hex(raw,2)).'," "))
        end

        % Plot each successfully decoded sensor in its own figure.
        if ~isempty(Y)
            figure('Name',"PocketLab - " + key);
            plot(t,Y,'LineWidth',1.1);
            xlabel('Time [s]');

            if info.Validated
                ylabel(info.Unit);
            else
                ylabel('Native decoded value (experimental)');
            end

            title("PocketLab Voyager 2: " + info.Sensor);
            grid on

            labels = string(info.ChannelLabels);
            if numel(labels) == size(Y,2)
                legend(labels,'Location','best');
            end
        end

    catch ME
        fprintf('\nTEST FAILED for %s\n',key);
        fprintf('%s\n',ME.message);

        results.(key).error = ME.message;
    end

    fprintf('\nTest complete: %s\n',key);
end

%% Summary
fprintf('\n============================================================\n');
fprintf('PocketLab sensor demo complete.\n');
fprintf('Results are stored in the workspace variable: results\n');
fprintf('Examples:\n');
fprintf('  results.acceleration.Y\n');
fprintf('  results.gyroscope.info.RawPackets{1}\n');
fprintf('============================================================\n');

%% Optional derived rangefinder signals
% These streams are defined in the public Voyager 2 configuration but are
% not included in the main loop because they may depend on rangefinder
% operation and still require protocol validation.
%
% Uncomment and test individually after the basic rangefinder stream works:
%
% [t,d] = pocketlabRead("displacement",5,20);
% [t,v] = pocketlabRead("velocity",5,20);
% [t,a] = pocketlabRead("rangeacceleration",5,20);
%
% External probe input is also available experimentally:
%
% [t,V] = pocketlabRead("external",5,20,"ExternalMode","voltage");
% [t,R] = pocketlabRead("external",5,20,"ExternalMode","resistance");
% [t,I] = pocketlabRead("external",5,20,"ExternalMode","current");
% [t,T] = pocketlabRead("external",5,20,"ExternalMode","temperature");
