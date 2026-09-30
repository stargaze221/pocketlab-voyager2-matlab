function level = pocketlabBattery(varargin)
%POCKETLABBATTERY Read PocketLab Voyager 2 battery level [%].
%
%   level = pocketlabBattery
%   level = pocketlabBattery("Address",address)
%
% By default, the function uses the BLE address saved by pocketlabPair.
% The returned value is the standard BLE Battery Level characteristic
% expressed as percent (0-100).

p = inputParser;
addParameter(p,'Address',"",@(x)ischar(x) || isstring(x));
parse(p,varargin{:});

address = string(p.Results.Address);

if strlength(address) == 0
    pairingFile = fullfile(fileparts(mfilename('fullpath')), ...
        'pocketlab_pairing.mat');

    if ~isfile(pairingFile)
        error(['No PocketLab pairing was found. Run pocketlabPair first, ' ...
            'or call pocketlabBattery("Address",address).']);
    end

    S = load(pairingFile,'pairing');
    address = string(S.pairing.Address);
end

b = ble(address);

% Standard Bluetooth SIG Battery Service / Battery Level characteristic.
batteryCharacteristic = characteristic(b,"180F","2A19");
rawLevel = read(batteryCharacteristic);

level = double(rawLevel(1));

fprintf('PocketLab battery: %d %%\n',round(level));
end
