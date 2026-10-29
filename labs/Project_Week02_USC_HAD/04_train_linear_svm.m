%% ME 3310 | Project Week 2 | Train a TWO-feature linear SVM
% 04_train_linear_svm.m
%
% We train on windows from one set of people and TEST on held-out people.
% This is crucial: randomly splitting overlapping windows would leak
% information and give overly optimistic test performance.
%
% Requires Statistics and Machine Learning Toolbox (fitcsvm).
% Up (0) vs Down (1) is the only target of this binary classifier.

clear; clc;
scriptFolder = fileparts(mfilename('fullpath'));
if isempty(scriptFolder), scriptFolder=pwd; end
source = fullfile(scriptFolder,'ME3310_USC_HAD_WindowFeatures.mat');
if ~isfile(source)
    error('Run 03_extract_window_features.m first.');
end
load(source,'X','Y','featureNames','classNames', ...
    'subjectID','trialID','recordID','windowEndTime', ...
    'windowSeconds','hopSeconds');
assert(exist('fitcsvm','file')==2, ...
    'Statistics and Machine Learning Toolbox (fitcsvm) is required.');

%% STUDENT EXPERIMENT: choose two interpretable features
% Run 03 first to visualize candidates; try other indices here.
featureIdx = [1 2]; % acceleration STD and acceleration PSD band power
assert(numel(featureIdx)==2 && all(featureIdx>=1) && ...
    all(featureIdx<=size(X,2)) && featureIdx(1)~=featureIdx(2), ...
    'Select TWO distinct feature column numbers.');
Z = X(:,featureIdx);

%% Train/test split by ENTIRE SUBJECT, not by overlapping windows
subjects = unique(subjectID);
assert(numel(subjects)>=3,'Need at least three subjects for this example.');
rng(3310); % reproducible selection of held-out subjects
subjects = subjects(randperm(numel(subjects)));
nTrainSubject = max(2,floor(0.75*numel(subjects)));
trainMask = ismember(subjectID,subjects(1:nTrainSubject));
testMask = ~trainMask;
assert(any(testMask) && numel(unique(Y(trainMask)))==2 && ...
    numel(unique(Y(testMask)))==2, ...
    'Train and test must each include BOTH activity classes.');

fprintf('Training subjects: %s\n',mat2str(sort(subjects(1:nTrainSubject))'));
fprintf('Held-out subjects: %s\n',mat2str(sort(subjects(nTrainSubject+1:end))'));
fprintf('Training windows: %d, held-out windows: %d\n', ...
    nnz(trainMask),nnz(testMask));

%% TRAINING: estimate model parameters using labeled training windows
model = fitcsvm(Z(trainMask,:),Y(trainMask), ...
    'KernelFunction','linear', ...
    'Standardize',true, ...
    'ClassNames',[0 1]);

%% TESTING: no model refitting occurs in predict()
trainPred = predict(model,Z(trainMask,:));
testPred = predict(model,Z(testMask,:));
trainAccuracy = 100*mean(trainPred==Y(trainMask));
testAccuracy = 100*mean(testPred==Y(testMask));

fprintf('Training window accuracy: %.1f%%\n',trainAccuracy);
fprintf('Held-out-subject WINDOW accuracy: %.1f%%\n',testAccuracy);
fprintf(['WARNING: overlapping test windows are correlated; ' ...
    'the percentage is not an uncertainty estimate.\n']);

%% Figure 1: feature space plus learned linear decision boundary
x1 = linspace(min(Z(:,1)),max(Z(:,1)),120);
x2 = linspace(min(Z(:,2)),max(Z(:,2)),120);
[A,B] = meshgrid(x1,x2);
[~,scores] = predict(model,[A(:),B(:)]);
scoreGrid = reshape(scores(:,2),size(A)); % score for class 1

figure('Name','Linear SVM: held-out-subject test'); hold on;
scatter(Z(trainMask & Y==0,1),Z(trainMask & Y==0,2), ...
    9,'filled','DisplayName','Upstairs: train');
scatter(Z(trainMask & Y==1,1),Z(trainMask & Y==1,2), ...
    9,'filled','DisplayName','Downstairs: train');
scatter(Z(testMask & Y==0,1),Z(testMask & Y==0,2), ...
    30,'o','LineWidth',1,'DisplayName','Upstairs: held out');
scatter(Z(testMask & Y==1,1),Z(testMask & Y==1,2), ...
    30,'x','LineWidth',1,'DisplayName','Downstairs: held out');
contour(A,B,scoreGrid,[0 0],'k','LineWidth',2, ...
    'DisplayName','SVM decision boundary');
xlabel(featureNames{featureIdx(1)});
ylabel(featureNames{featureIdx(2)});
title(sprintf('Linear SVM, held-out-subject accuracy %.1f%%',testAccuracy));
legend('Location','best'); grid on;

%% Figure 2: classification error types on held-out subjects
figure('Name','Held-out-subject confusion matrix');
confusionchart(Y(testMask),testPred, ...
    'Title','Upstairs (0) vs Downstairs (1) — held-out subjects');

%% Report per-person performance, rather than treating windows as trials
heldOut = unique(subjectID(testMask));
for i = 1:numel(heldOut)
    maskWithinTest = subjectID(testMask)==heldOut(i);
    acc = mean(testPred(maskWithinTest)==Y(testMask & ...
        subjectID==heldOut(i)))*100;
    fprintf('Held-out subject %d: %.1f%% (%d windows)\n', ...
        heldOut(i),acc,nnz(maskWithinTest));
end

%% Figure 3: time-varying classifier output within ONE complete test trial
% The original USC-HAD recordings contain ONE activity per trial.
% This plot shows predictions over time but NOT genuine activity transitions.
testRecordIds = unique(recordID(testMask));
if ~isempty(testRecordIds)
    selectedRecord = testRecordIds(1);
    idxInTest = recordID(testMask)==selectedRecord;
    tTest = windowEndTime(testMask);
    yTest = Y(testMask);
    figure('Name','Sliding-window predictions within one held-out trial');
    stairs(tTest(idxInTest),testPred(idxInTest),'LineWidth',1.5);
    hold on;
    yline(yTest(find(idxInTest,1)),'k--','True class');
    ylim([-0.25 1.25]); yticks([0 1]); yticklabels(classNames);
    xlabel('Window end time (s)');
    ylabel('Predicted activity');
    title(sprintf('Held-out trial %d, %0.1f-s window / %0.1f-s hop', ...
        selectedRecord,windowSeconds,hopSeconds));
    grid on;
end

%% Engineering interpretation
% - Does the model outperform a simple one-feature threshold?
% - Do new subjects produce more errors than training subjects?
% - How does changing the window length change the result?
% - Why are confidence intervals based on individual windows misleading?
% - What new independent experiment would test real motion transitions?
