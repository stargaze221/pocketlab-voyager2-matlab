function [t,data,info] = pocketlabMemoryDownload(varargin)
%POCKETLABMEMORYDOWNLOAD Download/decode Voyager 2 internal flash data.
%
%   [t,data,info] = pocketlabMemoryDownload()
%   [t,data,info] = pocketlabMemoryDownload("FilePrefix","Lab04")
%
%   Uses pocketlabMemoryProbe (raw download) and pocketlabDecodeMemory
%   (offline decoding). Saves raw and decoded MAT files.
%   It does NOT erase stored recordings. Nominal Fs=20 Hz unless supplied
%   otherwise; sample times are NOT hardware timestamps.
%
%   Options: "Address", "FilePrefix", "MaxDuration_s".
p=inputParser;
addParameter(p,'Address',"",@(v)isstring(v)||ischar(v));
addParameter(p,'FilePrefix',"",@(v)isstring(v)||ischar(v));
addParameter(p,'MaxDuration_s',180,@(v)isnumeric(v)&&isscalar(v)&&isfinite(v)&&v>0);
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
info=struct();
info.RawCapture=probeInfo;
info.Decoding=decodeMeta;
info.RawFile=string(rawFile);
info.DecodedFile=string(decodedFile);
info.DownloadComplete=probeInfo.EndMarkerSeen;
info.HardwareSampleTimestampsVerified=false;
save(decodedFile,'t','data','info');

fprintf('Saved raw: %s\n',rawFile);
fprintf('Saved decoded: %s\n',decodedFile);
fprintf('Decoded samples: %d | nominal rate: %g Hz\n', ...
    numel(t),decodeMeta.NominalFrequencyHz);
if ~info.DownloadComplete
    warning('PocketLab:IncompleteMemoryDownload', ...
        'Download completion was not confirmed. Inspect raw capture.');
end
end
