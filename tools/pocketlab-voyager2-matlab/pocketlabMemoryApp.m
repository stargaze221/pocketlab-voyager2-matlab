function fig = pocketlabMemoryApp()
%POCKETLABMEMORYAPP Graphical interface for Voyager 2 internal Memory Mode.
%
%   pocketlabMemoryApp
%
%   All hardware commands are delegated to pocketlabMemoryProbe,
%   pocketlabMemoryClear, pocketlabMemoryStart, pocketlabMemoryStop, and
%   pocketlabMemoryDownload. The GUI does not issue raw BLE writes.
%
%   Memory Mode tested at nominal 20 Hz. Sensor groups beyond the tested
%   configurations remain experimental. Download always saves full raw
%   capture and decoded MAT files (with automatic timestamped names).
%   No sample-wise hardware timestamps have been verified.
%
%   IMPORTANT: Disconnect the PocketLab Notebook browser application
%   before using this GUI. Device memory clear is DESTRUCTIVE and requires
%   a separate confirmation every time. The GUI never auto-erases.

groups = ["acceleration","gyroscope","magnetometer", ...
    "roll","pitch","heading","quaternion", ...
    "temperature","pressure","humidity","altitude", ...
    "dewpoint","heatindex","ambientlight","uvlight", ...
    "irlight","rangefinder"];
labels = ["Acceleration (XYZ)","Gyroscope (XYZ)", ...
    "Magnetometer (XYZ)","Roll","Pitch","Heading","Quaternion", ...
    "Temperature","Pressure","Humidity","Altitude", ...
    "Dew point","Heat index","Ambient light","UV light", ...
    "IR light","Rangefinder"];

deviceState = "Unknown";
isBusy = false;
lastTime = [];
lastData = struct();
lastDownloadInfo = struct();
logLines = ["PocketLab Voyager 2 — Memory Mode"; ...
    "Disconnect the browser app before using Bluetooth."; ...
    "Press Refresh Status first. Recording rate: nominal 20 Hz."];

fig = uifigure('Name','PocketLab Voyager 2 | Memory Mode', ...
    'Position',[100 100 1090 750], ...
    'CloseRequestFcn',@onCloseWindow);

main = uigridlayout(fig,[5 1]);
main.RowHeight = {50,210,38,112,'1x'};
main.ColumnWidth = {'1x'};
main.Padding = [14 12 14 12];
main.RowSpacing = 9;

header = uigridlayout(main,[1 2]);
header.Layout.Row = 1;
header.ColumnWidth = {'1x','1x'};
header.Padding = [0 0 0 0];

titleLabel = uilabel(header,'Text','PocketLab Voyager 2 — Memory Mode', ...
    'FontSize',19,'FontWeight','bold');
titleLabel.Layout.Column = 1;

stateLabel = uilabel(header,'Text','Device: Unknown | Press Refresh Status', ...
    'FontSize',13,'HorizontalAlignment','right');
stateLabel.Layout.Column = 2;

sensorPanel = uipanel(main,'Title','Select sensors to RECORD on the device');
sensorPanel.Layout.Row = 2;
sensorGrid = uigridlayout(sensorPanel,[5 4]);
sensorGrid.RowHeight = {'1x','1x','1x','1x','1x'};
sensorGrid.ColumnWidth = {'1x','1x','1x','1x'};
sensorGrid.Padding = [10 9 10 7];
sensorGrid.RowSpacing = 3;
sensorGrid.ColumnSpacing = 8;

sensorBoxes = cell(1,numel(groups));
for k=1:numel(groups)
    cb = uicheckbox(sensorGrid,'Text',char(labels(k)), ...
        'Value',ismember(groups(k),["acceleration","gyroscope"]));
    cb.Layout.Row = ceil(k/4);
    cb.Layout.Column = mod(k-1,4)+1;
    sensorBoxes{k} = cb;
end

presets = uigridlayout(main,[1 6]);
presets.Layout.Row = 3;
presets.ColumnWidth = {'1x','1x','1x','1x','1x','2x'};
presets.Padding = [0 0 0 0];
presets.ColumnSpacing = 8;

imuPreset = uibutton(presets,'push','Text','IMU preset', ...
    'ButtonPushedFcn',@(~,~)setPreset( ...
    ["acceleration","gyroscope","magnetometer"]));
envPreset = uibutton(presets,'push','Text','Environment', ...
    'ButtonPushedFcn',@(~,~)setPreset( ...
    ["temperature","pressure","humidity"]));
lightPreset = uibutton(presets,'push','Text','Light', ...
    'ButtonPushedFcn',@(~,~)setPreset( ...
    ["ambientlight","uvlight"]));
attitudePreset = uibutton(presets,'push','Text','Attitude', ...
    'ButtonPushedFcn',@(~,~)setPreset( ...
    ["roll","pitch","heading","quaternion"]));
allPreset = uibutton(presets,'push','Text','All', ...
    'ButtonPushedFcn',@(~,~)setPreset(groups));
noteLabel = uilabel(presets, ...
    'Text','Nominal 20 Hz · Other sensor combinations are experimental', ...
    'FontAngle','italic');
noteLabel.Layout.Column = 6;

controls = uipanel(main,'Title','Device control and acquisition');
controls.Layout.Row = 4;
controlsGrid = uigridlayout(controls,[2 6]);
controlsGrid.RowHeight = {34,30};
controlsGrid.ColumnWidth = {'1x','1x','1x','1x','1x','1x'};
controlsGrid.Padding = [9 9 9 5];
controlsGrid.RowSpacing = 6;
controlsGrid.ColumnSpacing = 8;

refreshButton = uibutton(controlsGrid,'push','Text','Refresh Status', ...
    'ButtonPushedFcn',@(~,~)performAction("refresh"));
clearButton = uibutton(controlsGrid,'push','Text','Clear Device', ...
    'ButtonPushedFcn',@(~,~)performAction("clear"));
startButton = uibutton(controlsGrid,'push','Text','Start Recording', ...
    'ButtonPushedFcn',@(~,~)performAction("start"));
stopButton = uibutton(controlsGrid,'push','Text','Stop Recording', ...
    'ButtonPushedFcn',@(~,~)performAction("stop"));
downloadButton = uibutton(controlsGrid,'push','Text','Download & Plot', ...
    'ButtonPushedFcn',@(~,~)performAction("download"));
openButton = uibutton(controlsGrid,'push','Text','Open MAT File', ...
    'ButtonPushedFcn',@(~,~)performAction("open"));

prefixLabel = uilabel(controlsGrid,'Text','File prefix (optional):');
prefixLabel.Layout.Row = 2;
prefixLabel.Layout.Column = 1;

filePrefix = uieditfield(controlsGrid,'text','Value','', ...
    'Placeholder','Automatic timestamp if blank');
filePrefix.Layout.Row = 2;
filePrefix.Layout.Column = [2 4];

timeoutLabel = uilabel(controlsGrid,'Text','Download timeout (s):', ...
    'HorizontalAlignment','right');
timeoutLabel.Layout.Row = 2;
timeoutLabel.Layout.Column = 5;

timeoutSpinner = uispinner(controlsGrid,'Limits',[10 600], ...
    'Step',5,'Value',90);
timeoutSpinner.Layout.Row = 2;
timeoutSpinner.Layout.Column = 6;

bottom = uigridlayout(main,[1 2]);
bottom.Layout.Row = 5;
bottom.ColumnWidth = {'2.5x','1x'};
bottom.RowHeight = {'1x'};
bottom.Padding = [0 0 0 0];
bottom.ColumnSpacing = 10;

plotAxes = uiaxes(bottom);
plotAxes.Layout.Column = 1;
title(plotAxes,'Load or download a recording to see data');
xlabel(plotAxes,'Nominal Time (s)');
ylabel(plotAxes,'Sensor output (native units)');
grid(plotAxes,'on');

right = uigridlayout(bottom,[3 1]);
right.Layout.Column = 2;
right.RowHeight = {23,32,'1x'};
right.Padding = [0 0 0 0];
right.RowSpacing = 6;

plotSelectLabel = uilabel(right,'Text','Sensor shown in plot:');
plotSelectLabel.Layout.Row = 1;

plotSelect = uidropdown(right,'Items',{'No data'},'Value','No data', ...
    'Enable','off','ValueChangedFcn',@(~,~)plotCurrent());
plotSelect.Layout.Row = 2;

logArea = uitextarea(right,'Value',cellstr(logLines),'Editable','off');
logArea.Layout.Row = 3;

updateControls();

    function updateControls()
        enabled = ~isBusy;
        refreshButton.Enable = switchState(enabled);
        openButton.Enable = switchState(enabled);
        clearButton.Enable = switchState(enabled && deviceState=="Recorded");
        startButton.Enable = switchState(enabled && deviceState=="Empty");
        stopButton.Enable = switchState(enabled && deviceState=="Recording");
        downloadButton.Enable = switchState(enabled && deviceState=="Recorded");
        filePrefix.Enable = switchState(enabled);
        timeoutSpinner.Enable = switchState(enabled);
        for j=1:numel(sensorBoxes)
            sensorBoxes{j}.Enable = switchState(enabled && deviceState~="Recording");
        end
        buttons = {imuPreset,envPreset,lightPreset,attitudePreset,allPreset};
        for j=1:numel(buttons)
            buttons{j}.Enable = switchState(enabled && deviceState~="Recording");
        end
        stateLabel.Text = char("Device: "+deviceState);
        drawnow limitrate;
    end

    function mode = switchState(value)
        if value
            mode = 'on';
        else
            mode = 'off';
        end
    end

    function setPreset(names)
        for j=1:numel(groups)
            sensorBoxes{j}.Value = ismember(groups(j),names);
        end
    end

    function selected = selectedSensors()
        selected = strings(1,0);
        for j=1:numel(groups)
            if sensorBoxes{j}.Value
                selected(end+1) = groups(j); %#ok<AGROW>
            end
        end
    end

    function addLog(message)
        entry = string(datestr(now,'HH:MM:SS'))+" | "+string(message);
        logLines = [logLines; entry]; %#ok<AGROW>
        if numel(logLines)>100
            logLines = logLines(end-99:end);
        end
        logArea.Value = cellstr(logLines);
        drawnow limitrate;
    end

    function performAction(action)
        if isBusy, return; end

        if action=="clear"
            answer = uiconfirm(fig, ...
                ['Erase the Voyager 2 DEVICE memory permanently?' newline ...
                 'Previously downloaded .mat files are not affected.' newline ...
                 'Make sure this recording was backed up first.'], ...
                'Confirm memory deletion', ...
                'Options',{'Cancel','Erase Device Memory'}, ...
                'DefaultOption',1,'CancelOption',1,'Icon','warning');
            if ~strcmp(answer,'Erase Device Memory')
                addLog("Clear cancelled");
                return
            end
        end

        isBusy = true;
        updateControls();
        try
            switch action
                case "refresh"
                    r = pocketlabMemoryProbe("status");
                    deviceState = string(r.MemoryState);
                    addLog("Status: "+deviceState);

                case "clear"
                    r = pocketlabMemoryClear("ConfirmErase",true);
                    if r.EmptyConfirmed
                        deviceState = "Empty";
                        addLog("Device flash is Empty (confirmed)");
                    else
                        deviceState = "Unknown";
                        addLog("Clear was sent, but Empty was NOT confirmed");
                    end

                case "start"
                    selected = selectedSensors();
                    if isempty(selected)
                        error('Select at least one sensor before recording.');
                    end
                    addLog("Requesting 20 Hz recording: "+ ...
                        strjoin(selected,", "));
                    r = pocketlabMemoryStart(20,"Sensors",selected);
                    if r.StartConfirmed
                        deviceState = "Recording";
                        addLog("Recording on the device. Press Stop when ready.");
                    else
                        deviceState = "Unknown";
                        addLog("Start sent but recording state is unconfirmed.");
                    end

                case "stop"
                    r = pocketlabMemoryStop();
                    if r.StopConfirmed
                        deviceState = "Recorded";
                        addLog("Recording stopped. Ready to download.");
                    else
                        deviceState = "Unknown";
                        addLog("Stop not confirmed. Refresh Status.");
                    end

                case "download"
                    prefix = strtrim(string(filePrefix.Value));
                    if strlength(prefix)==0
                        [lastTime,lastData,lastDownloadInfo] = ...
                            pocketlabMemoryDownload( ...
                            "MaxDuration_s",timeoutSpinner.Value);
                    else
                        [lastTime,lastData,lastDownloadInfo] = ...
                            pocketlabMemoryDownload( ...
                            "FilePrefix",prefix, ...
                            "MaxDuration_s",timeoutSpinner.Value);
                    end
                    updatePlotChoices();
                    if lastDownloadInfo.DownloadComplete
                        addLog("Download complete: "+numel(lastTime)+ ...
                            " samples; decoded file: "+ ...
                            lastDownloadInfo.DecodedFile);
                    else
                        addLog("WARNING: incomplete download. Raw and decoded files saved.");
                        uialert(fig, ...
                            ['Download completion marker was not received. ' ...
                             'The decoded output may be incomplete; ' ...
                             'preserve the raw .mat file.'], ...
                            'Incomplete download','Icon','warning');
                    end

                case "open"
                    [file,folder] = uigetfile('*.mat','Open decoded PocketLab MAT file');
                    if isequal(file,0)
                        addLog("Open file cancelled");
                    else
                        S = load(fullfile(folder,file));
                        if ~isfield(S,'t') || ~isfield(S,'data') || ...
                                ~isstruct(S.data)
                            error('Select a decoded MAT file containing t and data.');
                        end
                        lastTime = S.t;
                        lastData = S.data;
                        if isfield(S,'info')
                            lastDownloadInfo = S.info;
                        else
                            lastDownloadInfo = struct();
                        end
                        updatePlotChoices();
                        addLog("Opened "+string(file)+ ...
                            " ("+numel(lastTime)+" samples)");
                    end
            end
        catch ME
            addLog("ERROR: "+string(ME.message));
            uialert(fig,ME.message,'PocketLab Memory Mode error','Icon','error');
            if any(action==["start","stop","clear"])
                deviceState = "Unknown";
                addLog("Refresh device status before another command.");
            end
        end
        isBusy = false;
        updateControls();
    end

    function updatePlotChoices()
        fields = fieldnames(lastData);
        if isempty(fields)
            plotSelect.Items = {'No data'};
            plotSelect.Value = 'No data';
            plotSelect.Enable = 'off';
            cla(plotAxes);
            return
        end
        plotSelect.Items = fields;
        plotSelect.Value = fields{1};
        plotSelect.Enable = 'on';
        plotCurrent();
    end

    function plotCurrent()
        if isempty(fieldnames(lastData)), return; end
        key = char(plotSelect.Value);
        if ~isfield(lastData,key), return; end
        values = lastData.(key);
        cla(plotAxes);

        if numel(lastTime)==size(values,1) && all(isfinite(lastTime))
            plot(plotAxes,lastTime,values,'LineWidth',1.1);
            xlabel(plotAxes,'Nominal Time (s)');
        else
            plot(plotAxes,values,'LineWidth',1.1);
            xlabel(plotAxes,'Sample index');
        end
        ylabel(plotAxes,[key ' (native units unless verified)']);
        title(plotAxes,[key ' — Memory Mode']);
        grid(plotAxes,'on');
        if size(values,2)==3
            legend(plotAxes,{'X','Y','Z'},'Location','best');
        elseif size(values,2)==4
            legend(plotAxes,{'q1','q2','q3','q4'},'Location','best');
        else
            legend(plotAxes,'off');
        end
    end

    function onCloseWindow(~,~)
        if isBusy
            uialert(fig,'Wait for the current operation to finish, then close.', ...
                'PocketLab is busy','Icon','warning');
            return
        end
        if deviceState=="Recording"
            answer = uiconfirm(fig, ...
                ['The device is still recording. Closing this GUI does ' ...
                 'NOT stop recording. Close anyway?'], ...
                'Recording in progress', ...
                'Options',{'Stay Open','Close GUI'}, ...
                'DefaultOption',1,'CancelOption',1,'Icon','warning');
            if ~strcmp(answer,'Close GUI'), return; end
        end
        delete(fig);
    end
end
