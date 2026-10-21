function [t,data,info] = pocketlabMemoryDownload(varargin)
%POCKETLABMEMORYDOWNLOAD Download/decode Voyager 2 internal flash data.
%
%   [t,data,info] = pocketlabMemoryDownload()
%   [t,data,info] = pocketlabMemoryDownload("FilePrefix","Lab04")
%   [t,data,info] = pocketlabMemoryDownload( ...
%       "Sensors",["acceleration","gyroscope"])
%
%   "Sensors" limits decoded MAT file fields after downloading; the raw
%   recording is always backed up in full. To reduce the data recorded on
%   the device, use pocketlabMemoryStart(20,"Sensors",...).
%
%   Uses pocketlabMemoryProbe (raw download) and pocketlabDecodeMemory
%   (offline decoding). Saves raw and decoded MAT files.
%   It does NOT erase stored recordings. Nominal Fs=20 Hz unless supplied
%   otherwise; sample times are NOT hardware timestamps.
%
%   Options: "Address", "FilePrefix", "MaxDuration_s", "Sensors".
p=inputParser;
addParameter(p,'Address',"",@(v)isstring(v)||ischar(v));
addParameter(p,'FilePrefix',"",@(v)isstring(v)||ischar(v));
addParameter(p,'MaxDuration_s',180,@(v)isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0);
addParameter(p,'Sensors',strings(1,0), ...
    @(v)isstring(v)||ischar(v)||iscellstr(v));
parse(p,varargin{:});

address=string(p.Results.Address);
prefix=string(p.Results.FilePrefix);
if strlength(prefix)==0
    prefix="pocketlab_memory_" + string(datestr(now,'yyyymmdd_HHMMSS'));
end
rawFile=char(prefix+"_raw.mat");
decodedFile=char(prefix+"_decoded.mat");
if isfile(rawFile)||isfile(decodedFile)
    error('Output files already exist; choose another FilePrefix.');
end

probeInfo=pocketlabMemoryProbe("download", ...
    "Address",address,"SaveFile",rawFile, ...
    "MaxDuration_s",p.Results.MaxDuration_s);

% Raw MAT is saved first even if subsequent decoding fails.
[t,data,decodeMeta]=pocketlabDecodeMemory(probeInfo,"FrequencyHz",20);

% Filter decoded values only when explicitly requested. Never discard raw.
requested=lower(strtrim(string(p.Results.Sensors(:).')));
if ~isempty(requested)
    if any(ismissing(requested)) || any(strlength(requested)==0) || ...
            numel(unique(requested))~=numel(requested)
        error('Sensors must be distinct, nonempty names. Raw data was saved.');
    end
    available=string(fieldnames(data));
    if ~all(ismember(requested,available))
        error('Requested sensors not present in recording. Available: %s. Raw data was saved.', ...
            strjoin(cellstr(available),', '));
    end
    fullData=data;
    data=struct();
    for k=1:numel(requested)
        key=char(requested(k));
        data.(key)=fullData.(key);
    end
end
info=struct();
info.RawCapture=probeInfo;
info.Decoding=decodeMeta;
info.SavedSensors=string(fieldnames(data)).';
info.SensorSaveFilterApplied=~isempty(requested);
info.RawFile=string(rawFile);
info.DecodedFile=string(decodedFile);
info.DownloadComplete=probeInfo.EndMarkerSeen;
info.HardwareSampleTimestampsVerified=false;
save(decodedFile,'t','data','info');

fprintf('Saved raw: %s\n',rawFile);
fprintf('Saved decoded: %s\n',decodedFile);
fprintf('Decoded samples: %d | nominal rate: %g Hz\n', ...
    numel(t),decodeMeta.NominalFrequencyHz);
fprintf('Saved sensor groups: %s\n',strjoin(cellstr(info.SavedSensors),', '));
if ~info.DownloadComplete
    warning('PocketLab:IncompleteMemoryDownload', ...
        'Download completion was not confirmed. Inspect raw capture.');
end
end
