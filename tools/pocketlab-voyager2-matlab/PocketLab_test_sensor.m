%% PocketLab Voyager 2 - Sensor Validation Helper
% Change "sensor" below and run.
%
% Suggested validation order:
%   "gyroscope"
%   "rangefinder"
%   "temperature"
%   "pressure"
%
% The script prints the first decoded values and raw packet bytes.

clear
clc

sensor = "gyroscope";
recordTime = 5;
Fs = 20;

[t,Y,info] = pocketlabRead(sensor,recordTime,Fs, ...
    "SuppressExperimentalWarning",true);

fprintf('\nSensor: %s\n',info.Sensor);
fprintf('Decoded size: %d x %d\n',size(Y,1),size(Y,2));

disp('First decoded values:')
disp(Y(1:min(10,end),:))

if ~isempty(info.RawPackets)
    raw = info.RawPackets{1};
    fprintf('\nFirst raw packet (%d bytes):\n',numel(raw));
    disp(dec2hex(raw,2))
end

figure
plot(t,Y,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Native decoded value')
title("PocketLab: " + info.Sensor)
grid on
