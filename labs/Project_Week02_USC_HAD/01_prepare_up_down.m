%% ME 3310 | Project Week 2 | USC-HAD Upstairs vs Downstairs
% 01_prepare_up_down.m
%
% Download/reuse the official USC-HAD archive and collect the original
% continuous trials for activity 4 (Walking Upstairs) and activity 5
% (Walking Downstairs). The output contains NO synthetic data and NO
% sliding windows. Each record corresponds to a separate original trial.
%
% Base MATLAB; no add-on toolboxes needed.
% Official dataset: https://sipi.usc.edu/had/
% M. Zhang and A. A. Sawchuk, USC-HAD, SAGAware 2012.

clear; clc;
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder), scriptFolder = pwd; end

% To reuse an archive already downloaded elsewhere, change sourceFolder
% to the location containing USC-HAD.zip and/or USC_HAD_raw.
sourceFolder = scriptFolder;
if ~isfile(fullfile(sourceFolder,'USC-HAD.zip')) && ...
        ~isfolder(fullfile(sourceFolder,'USC_HAD_raw'))
    parentFolder = fileparts(scriptFolder);
    if isfile(fullfile(parentFolder,'USC-HAD.zip')) || ...
            isfolder(fullfile(parentFolder,'USC_HAD_raw'))
        sourceFolder = parentFolder;
    end
end

zipURL = 'https://sipi.usc.edu/had/USC-HAD.zip';
zipPath = fullfile(sourceFolder,'USC-HAD.zip');
rawDir = fullfile(sourceFolder,'USC_HAD_raw');
outPath = fullfile(scriptFolder,'ME3310_USC_HAD_UpDown.mat');

%% Download/unzip only when needed
upFiles = dir(fullfile(rawDir,'**','a4t*.mat'));
downFiles = dir(fullfile(rawDir,'**','a5t*.mat'));

if isempty(upFiles) || isempty(downFiles)
    if ~isfile(zipPath)
        fprintf('Downloading the official USC-HAD archive...\n');
        try
            websave(zipPath,zipURL,weboptions('Timeout',180));
        catch ME
            error(['Automatic download failed: %s\nDownload the official ' ...
                'archive from %s and put USC-HAD.zip in %s.'], ...
                ME.message,zipURL,sourceFolder);
        end
    else
        fprintf('Reusing ZIP: %s\n',zipPath);
    end
    if ~isfolder(rawDir), mkdir(rawDir); end
    unzip(zipPath,rawDir);
end

%% Extract complete activity trials
fs = 100; % Hz, documented USC-HAD sampling frequency
classNames = {'Walking Upstairs','Walking Downstairs'};
records = struct('subject',{},'trial',{},'activityID',{},'label',{}, ...
    'activity',{},'acc',{},'gyro',{},'t',{},'sourceFile',{});

for activityID = [4,5]
    matching = dir(fullfile(rawDir,'**',sprintf('a%dt*.mat',activityID)));
    fprintf('%s: %d trial files found\n', ...
        classNames{activityID-3},numel(matching));

    for i = 1:numel(matching)
        src = fullfile(matching(i).folder,matching(i).name);
        S = load(src);
        if ~isfield(S,'sensor_readings') || ...
                ~isnumeric(S.sensor_readings) || ...
                size(S.sensor_readings,2)<6 || size(S.sensor_readings,1)<2
            warning('Skipping file with missing/invalid sensor_readings: %s',src);
            continue;
        end

        srcNorm = strrep(src,'\','/');
        subjTok = regexp(srcNorm,'Subject([0-9]+)', ...
            'tokens','once','ignorecase');
        trTok = regexp(matching(i).name,'^a([0-9]+)t([0-9]+)\.mat$', ...
            'tokens','once','ignorecase');
        if isempty(subjTok) || isempty(trTok)
            warning('Skipping file with unexpected name/path: %s',src);
            continue;
        end

        A = double(S.sensor_readings(:,1:6));
        r.subject = str2double(subjTok{1});
        r.trial = str2double(trTok{2});
        r.activityID = activityID;
        r.label = double(activityID==5); % 0=Up, 1=Down
        r.activity = classNames{r.label+1};
        r.acc = A(:,1:3);      % acceleration [g]
        r.gyro = A(:,4:6);     % angular velocity [deg/s]
        r.t = (0:size(A,1)-1)'/fs;
        r.sourceFile = src;
        records(end+1) = r; %#ok<SAGROW>
    end
end

if isempty(records) || ~any([records.label]==0) || ...
        ~any([records.label]==1)
    error('Both activities must exist in the official archive.');
end

[~,order] = sortrows([[records.subject]',[records.activityID]', ...
    [records.trial]']);
records = records(order);

save(outPath,'records','fs','classNames','zipURL','-v7.3');
fprintf('\nSaved: %s\n',outPath);
fprintf('Upstairs trials:   %d\n',sum([records.label]==0));
fprintf('Downstairs trials: %d\n',sum([records.label]==1));
fprintf('No segmentation or feature extraction was performed.\n');
