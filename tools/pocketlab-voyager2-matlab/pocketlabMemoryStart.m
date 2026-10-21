function info = pocketlabMemoryStart(Fs,varargin)
%POCKETLABMEMORYSTART Start a Voyager 2 internal-memory recording.
%   info = pocketlabMemoryStart(20)
%   info = pocketlabMemoryStart(20, ...
%       "Sensors",["acceleration","gyroscope"])
%
%   Sensor groups: acceleration, gyroscope, magnetometer, heading,
%   pitch, roll, quaternion, temperature, pressure, humidity, altitude,
%   dewpoint, heatindex, rangefinder, uvlight, ambientlight, irlight.
%   Default = established seven-group (16-channel) IMU+attitude profile.
%   Sensor-subset Flash recording is EXPERIMENTAL until hardware tested.
%   Environmental/light/rangefinder groups are newly supported but have
%   NOT YET been physically validated in offline Memory Mode.
%
%   Experimental on firmware VP.1.2. Supports the previously observed
%   20 Hz, 16-channel flash format. Refuses to start when recording data
%   exists; no erase operation is included here.
%
%   The official web app writes user-space metadata before starting.
%   This initial non-erasing prototype intentionally omits that operation.
%   Start-time metadata may be absent in resulting recordings.
%
%   Optional: "Address" (BLE address; defaults to paired device),
%             "Sensors" (string array of sensor groups).
if nargin < 1
    error('Specify the sample rate, e.g. pocketlabMemoryStart(20).');
end
validateattributes(Fs,{'numeric'},{'scalar','real','finite'},mfilename,'Fs');
if Fs ~= 20
    error('Initial Memory Mode prototype supports Fs=20 Hz only.');
end
p=inputParser;
addParameter(p,'Address',"",@(v)isstring(v)||ischar(v));
addParameter(p,'Sensors',["acceleration","gyroscope","magnetometer", ...
    "heading","pitch","roll","quaternion"], ...
    @(v)isstring(v)||ischar(v)||iscellstr(v));
parse(p,varargin{:});

sensorNames=lower(strtrim(string(p.Results.Sensors(:).')));
if isempty(sensorNames) || any(ismissing(sensorNames)) || ...
        any(strlength(sensorNames)==0) || ...
        numel(unique(sensorNames))~=numel(sensorNames)
    error('Sensors must be a nonempty list of distinct names.');
end
registry=pocketlabSensorRegistry();
allowed=["acceleration","gyroscope","magnetometer", ...
    "heading","pitch","roll","quaternion", ...
    "temperature","pressure","humidity","altitude","dewpoint", ...
    "heatindex","rangefinder","uvlight","ambientlight","irlight"];
if ~all(ismember(sensorNames,allowed))
    error('Memory recording supports: %s.',strjoin(cellstr(allowed),', '));
end
configurationMask=uint32(0);
for i=1:numel(sensorNames)
    sensor=registry.(char(sensorNames(i)));
    configurationMask=bitor(configurationMask,sensor.ConfigValue);
end
maskBytes=uint8([ ...
    bitand(configurationMask,uint32(255)), ...
    bitand(bitshift(configurationMask,-8),uint32(255)), ...
    bitand(bitshift(configurationMask,-16),uint32(255)), ...
    bitand(bitshift(configurationMask,-24),uint32(255))]);
address=string(p.Results.Address);
if strlength(address)==0
    folder=fileparts(mfilename('fullpath'));
    saved=load(fullfile(folder,'pocketlab_pairing.mat'),'pairing');
    address=string(saved.pairing.Address);
end

svc="152FDEA4-28A1-11ED-A261-0242AC120002";
b=ble(address);
tx=characteristic(b,svc,"152FDEA5-28A1-11ED-A261-0242AC120002");
rx=characteristic(b,svc,"152FDEA6-28A1-11ED-A261-0242AC120002");

before=localStatus(tx,rx);
if ~before.Valid
    error('Unrecognized memory status; refusing to start a recording.');
end
if before.Recording
    error('Device already reports Memory Mode recording.');
end
if before.Recorded
    error(['Voyager 2 already has stored data. This prototype does not ' ...
        'erase or overwrite it. Back up data and clear via official app ' ...
        'before starting a new recording.']);
end

% Experimental command sequence based on observed browser protocol:
% sampling instruction 0x00960003 (20 Hz), selected sensor mask.
% The 20 Hz instruction/3-samples-per-chunk was captured for 16 channels;
% subsets may produce a different chunk layout, checked during decode.
write(tx,uint8([108 1]),"withresponse");
pause(0.10);
write(tx,uint8([112 150 0 3 0]),"withresponse");
pause(0.10);
write(tx,uint8([110 maskBytes]),"withresponse");
pause(0.10);
write(tx,uint8([96 0]),"withresponse");
pause(0.10);
write(tx,uint8([106 1]),"withresponse");
pause(0.20);

after=localStatus(tx,rx);
info=struct();
info.Address=address;
info.FrequencyHz=20;
info.ConfigurationMask=configurationMask;
info.RequestedSensors=sensorNames;
info.SensorSubsetVerified=false;
info.StartCommandSent=true;
info.StartConfirmed=after.Valid && after.Recording;
info.StatusBefore=before;
info.StatusAfter=after;
info.UserSpaceMetadataWritten=false;
info.HardwareValidated=false;
fprintf('Requested sensors: %s | mask: 0x%s\n', ...
    strjoin(cellstr(sensorNames),', '),dec2hex(configurationMask,8));
fprintf('Memory START sent. Recording confirmed: %d. Status: %s\n', ...
    info.StartConfirmed,localHex(after.Response));
if ~info.StartConfirmed
    warning('PocketLab:StartUnconfirmed', ...
        ['Start command sent but device status did not confirm recording. ' ...
         'Check memory state before another attempt.']);
end
end

function st=localStatus(tx,rx)
write(tx,uint8(35),"withresponse");
pause(0.10);
write(tx,uint8(35),"withresponse");
pause(0.10);
raw=uint8(read(rx));
st=struct('Response',raw,'Valid',false,'Recording',false, ...
    'Recorded',false,'Flags',NaN);
if numel(raw)>=3 && raw(1)==17
    st.Valid=true;
    st.Flags=double(raw(3));
    st.Recording=bitand(raw(3),uint8(8))~=0;
    st.Recorded=bitand(raw(3),uint8(1))~=0;
end
end

function s=localHex(bytes)
s=strjoin(compose('%02X',uint8(bytes)), ' ');
end
