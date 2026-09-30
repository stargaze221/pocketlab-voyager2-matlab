function T = pocketlabSensors()
%POCKETLABSENSORS List Voyager 2 sensors currently included in the driver.
%
%   T = pocketlabSensors()
%
% "Validated" means physically checked with this MATLAB driver.
% At present, only acceleration has been physically validated.

S = pocketlabSensorRegistry();

names = string(fieldnames(S));
n = numel(names);

Sensor = strings(n,1);
Channels = zeros(n,1);
ValueLength_bytes = zeros(n,1);
ConfigValue = zeros(n,1);
Unit = strings(n,1);
Validated = false(n,1);

for k = 1:n
    s = S.(names(k));
    Sensor(k) = s.DisplayName;
    Channels(k) = s.NumChannels;
    ValueLength_bytes(k) = s.ValueLength;
    ConfigValue(k) = double(s.ConfigValue);
    Unit(k) = s.Unit;
    Validated(k) = s.Validated;
end

T = table(names,Sensor,Channels,ValueLength_bytes,ConfigValue,Unit,Validated, ...
    'VariableNames',{'Key','Sensor','Channels','ValueLength_bytes', ...
                     'ConfigValue','Unit','Validated'});

if nargout == 0
    disp(T)
    clear T
end
end
