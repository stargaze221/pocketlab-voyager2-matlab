%% ME 3310 | Project Week 2 | Preview USC-HAD IMU signals
% 02_preview_up_down.m
%
% Inspect TWO original complete trials from the saved Upstairs/Downstairs
% dataset. Do not interpret one trial pair as sufficient classification
% evidence. Plot raw accelerometer, gyroscope, magnitude and Welch PSD.
%
% Base MATLAB for time plots; Signal Processing Toolbox for pwelch.

clear; clc;
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder), scriptFolder = pwd; end
matPath = fullfile(scriptFolder,'ME3310_USC_HAD_UpDown.mat');
if ~isfile(matPath)
    error(['Missing data file: %s\nRun 01_prepare_up_down.m, ' ...
        'or copy an already prepared MAT file into this folder.'],matPath);
end
load(matPath,'records','fs','classNames');

%% Select one paired subject/trial to explore
preferredSubject = 1;
preferredTrial = 1;
upIdx = find([records.subject]==preferredSubject & ...
    [records.trial]==preferredTrial & [records.label]==0,1);
downIdx = find([records.subject]==preferredSubject & ...
    [records.trial]==preferredTrial & [records.label]==1,1);
if isempty(upIdx) || isempty(downIdx)
    error('Selected subject/trial not found; change the values above.');
end
up = records(upIdx);
down = records(downIdx);
maxSeconds = 12;

fprintf('Subject %d; trial %d; fs = %.0f Hz\n', ...
    preferredSubject,preferredTrial,fs);
fprintf('Upstairs duration %.2f s; Downstairs duration %.2f s\n', ...
    numel(up.t)/fs,numel(down.t)/fs);
fprintf('Upstairs mean gyro [gx gy gz] (deg/s): %s\n', ...
    mat2str(mean(up.gyro,1),3));
fprintf('Downstairs mean gyro [gx gy gz] (deg/s): %s\n', ...
    mat2str(mean(down.gyro,1),3));

%% Figure 1: raw IMU measurements (only the FIRST 12 s displayed)
figure('Name','USC-HAD: raw IMU');
tiledlayout(2,2,'TileSpacing','compact');
nexttile; mask=up.t<=maxSeconds;
plot(up.t(mask),up.acc(mask,:));
title('Upstairs: acceleration'); xlabel('Time (s)');
ylabel('Acceleration (g)'); legend('a_x','a_y','a_z'); grid on;

nexttile; mask=down.t<=maxSeconds;
plot(down.t(mask),down.acc(mask,:));
title('Downstairs: acceleration'); xlabel('Time (s)');
ylabel('Acceleration (g)'); legend('a_x','a_y','a_z'); grid on;

nexttile; mask=up.t<=maxSeconds;
plot(up.t(mask),up.gyro(mask,:));
title('Upstairs: angular velocity'); xlabel('Time (s)');
ylabel('Angular velocity (deg/s)'); legend('g_x','g_y','g_z'); grid on;

nexttile; mask=down.t<=maxSeconds;
plot(down.t(mask),down.gyro(mask,:));
title('Downstairs: angular velocity'); xlabel('Time (s)');
ylabel('Angular velocity (deg/s)'); legend('g_x','g_y','g_z'); grid on;

%% Figure 2: acceleration magnitude (includes the gravity component)
aUp = vecnorm(up.acc,2,2);
aDown = vecnorm(down.acc,2,2);
figure('Name','Acceleration magnitude'); hold on;
mu=up.t<=maxSeconds; md=down.t<=maxSeconds;
plot(up.t(mu),aUp(mu),'LineWidth',1.1);
plot(down.t(md),aDown(md),'LineWidth',1.1);
xlabel('Time (s)'); ylabel('Acceleration magnitude (g)');
title('Acceleration magnitude — first 12 seconds');
legend(classNames,'Location','best'); grid on;

%% Figure 3: PSD from COMPLETE trials, not the 12-s plot excerpt
% DC removal reduces the constant offset. The magnitude signal still
% depends on the motion and sensor placement.
if exist('pwelch','file')==2
    welchLength = 2*fs;
    if numel(aUp)>=welchLength && numel(aDown)>=welchLength
        nfft = 512;
        [Pu,f] = pwelch(aUp-mean(aUp),hamming(welchLength), ...
            floor(welchLength/2),nfft,fs);
        [Pd,~] = pwelch(aDown-mean(aDown),hamming(welchLength), ...
            floor(welchLength/2),nfft,fs);
        figure('Name','Welch PSD: acceleration magnitude');
        plot(f,10*log10(Pu+eps),'LineWidth',1.4); hold on;
        plot(f,10*log10(Pd+eps),'LineWidth',1.4);
        xlim([0 10]);
        xlabel('Frequency (Hz)'); ylabel('PSD (dB re 1 g^2/Hz)');
        title('Upstairs vs Downstairs — full-trial PSD');
        legend(classNames,'Location','best'); grid on;
    else
        fprintf('Trial too short for 2-s Welch segments.\n');
    end
else
    fprintf('PSD skipped: pwelch requires Signal Processing Toolbox.\n');
end

%% Engineering interpretation
% - Which measured axis differs most between these two trials?
% - What information about motion does magnitude eliminate?
% - Can one PSD comparison establish robust separation across subjects?
% Next: 03_extract_window_features.m
