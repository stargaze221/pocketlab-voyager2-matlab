function pairing = pocketlabPair(scanTime)
%POCKETLABPAIR Pair this computer with one PocketLab Voyager 2.
%
%   pocketlabPair
%   pocketlabPair(scanTime)
%   pairing = pocketlabPair(...)
%
% Workflow:
%   1) Scan nearby PocketLab devices.
%   2) Display them in RSSI order.
%   3) Select one device.
%   4) Optionally verify it by moving/shaking the sensor.
%   5) Save its BLE address for future automatic connection.
%
% The pairing file is stored next to this driver:
%   pocketlab_pairing.mat
%
% In a classroom, place YOUR PocketLab next to YOUR computer before
% scanning. The strongest RSSI is normally the best candidate, but always
% confirm the selected device.

if nargin < 1
    scanTime = 5;
end

validateattributes(scanTime, {'numeric'}, ...
    {'scalar','real','positive','finite'}, mfilename, 'scanTime');

pairingFile = fullfile(fileparts(mfilename('fullpath')), ...
    'pocketlab_pairing.mat');

fprintf('\nPocketLab Voyager 2 pairing\n');
fprintf('----------------------------\n');
fprintf('Place your PocketLab next to this computer.\n');
fprintf('Scanning for %.1f seconds...\n\n', scanTime);

% "PL" also permits renamed devices such as "PL ME3310-07".
devices = blelist("Name","PL","Timeout",scanTime);

if isempty(devices)
    error(['No PocketLab devices were found. Make sure the sensor is on, ' ...
        'advertising, and not connected to another computer/app.']);
end

fprintf('Nearby PocketLab candidates (strongest RSSI first):\n\n');
disp(devices(:,["Name","Address","RSSI"]));

n = height(devices);
choiceText = input(sprintf( ...
    'Select your device [1-%d] (press Enter for 1): ', n), 's');

if isempty(strtrim(choiceText))
    choice = 1;
else
    choice = str2double(choiceText);
end

if ~isscalar(choice) || isnan(choice) || choice < 1 || ...
        choice > n || choice ~= floor(choice)
    error('Invalid device selection.');
end

name    = string(devices.Name(choice));
address = string(devices.Address(choice));
rssi    = devices.RSSI(choice);

fprintf('\nSelected device:\n');
fprintf('  Name    : %s\n', name);
fprintf('  Address : %s\n', address);
fprintf('  RSSI    : %.0f dBm\n', rssi);

verifyText = input([ ...
    '\nPress Enter to verify by moving/shaking YOUR sensor for 2 seconds ' ...
    '(type S to skip): '], 's');

verified = false;
motionScore = NaN;

if ~strcmpi(strtrim(verifyText),'s')
    fprintf('\nMove/shake the selected PocketLab NOW...\n');

    try
        [~,A] = pocketlabRead("acceleration",2,20, ...
            "Address",address, ...
            "Quiet",true, ...
            "SuppressExperimentalWarning",true);

        if isempty(A)
            fprintf('No accelerometer samples were received.\n');
        else
            axisSpan = max(A,[],1) - min(A,[],1);
            motionScore = max(axisSpan);

            fprintf('Motion score: %.3f g\n',motionScore);

            if motionScore >= 0.15
                fprintf('Motion detected. This is likely your sensor.\n');
                verified = true;
            else
                fprintf(['Only weak motion was detected. Move the sensor more ' ...
                    'strongly if you want to verify again.\n']);
            end
        end
    catch ME
        fprintf('Verification could not be completed:\n  %s\n',ME.message);
    end
end

confirmText = input('\nSave this device as the paired PocketLab? [Y/n]: ','s');

if strcmpi(strtrim(confirmText),'n')
    fprintf('Pairing not saved. Run pocketlabPair again to choose another device.\n');
    pairing = struct([]);
    return
end

label = input( ...
    'Optional local label (for example ME3310-07; press Enter to skip): ', ...
    's');

pairing = struct;
pairing.Name          = name;
pairing.Address       = address;
pairing.RSSI          = rssi;
pairing.Label         = string(strtrim(label));
pairing.Verified      = verified;
pairing.MotionScore_g = motionScore;
pairing.PairedAt      = datetime('now');
pairing.DriverVersion = "2.0";

save(pairingFile,'pairing');

fprintf('\nPairing saved:\n  %s\n',pairingFile);

if strlength(pairing.Label) > 0
    fprintf('Local label: %s\n',pairing.Label);
end

if ismac
    fprintf(['\nNote: macOS uses an OS-assigned BLE address. If the sensor ' ...
        'cannot reconnect later, simply run pocketlabPair again.\n']);
end

fprintf('\nExamples:\n');
fprintf('  [t,A] = pocketlabRead("acceleration",10,20);\n');
fprintf('  [t,W] = pocketlabRead("gyroscope",10,20);\n\n');

end
