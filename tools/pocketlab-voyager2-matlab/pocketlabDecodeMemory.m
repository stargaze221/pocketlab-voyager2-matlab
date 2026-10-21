function [t,data,meta] = pocketlabDecodeMemory(info,varargin)
%POCKETLABDECODEMEMORY Decode recorded Voyager 2 standard-sensor flash.
%
%   [t,data,meta] = pocketlabDecodeMemory(info)
%   [t,data,meta] = pocketlabDecodeMemory(info,"FrequencyHz",20)
%
%   Pass the info struct from pocketlabMemoryProbe("download") or from a
%   saved raw .mat file. This decoder NEVER accesses the BLE device.
%
%   Flash framing confirmed by a real VP.1.2 recording:
%     0x96 + uint32 LE sensor mask + uint8 encoder-count (zero here)
%     + contiguous little-endian IEEE754 float32 standard-sensor values.
%
%   Time stamps are reconstructed from the NOMINAL sampling rate, NOT from
%   hardware sample timestamps. Web-app user-space metadata contains a
%   possible recording start POSIX time (source unverified).
%
%   Unsupported/ambiguous frames cause an error; no guessing.

validateattributes(info,{'struct'},{'scalar'},mfilename,'info');
if ~isfield(info,'RawPackets') || ~iscell(info.RawPackets)
    error('info.RawPackets must be a cell array of BLE payloads.');
end

parser=inputParser;
addParameter(parser,'FrequencyHz',NaN, ...
    @(x)isnumeric(x)&&isscalar(x)&&(isnan(x)||(isfinite(x)&&x>0)));
parse(parser,varargin{:});
rateOverride=double(parser.Results.FrequencyHz);

names={'acceleration','gyroscope','magnetometer', ...
    'heading','pitch','roll','quaternion'};
masks=uint32([112 896 7168 8192 16384 32768 65536]);
widths=[3 3 3 1 1 1 4];
labelNames={'acc_x','acc_y','acc_z','gyro_x','gyro_y','gyro_z', ...
    'mag_x','mag_y','mag_z','heading','pitch','roll', ...
    'q1','q2','q3','q4'};

X=zeros(0,0);
expectedMask=uint32(0);
selected=[];
samplesPerPacket=[];
flashCount=0;
emptyCount=0;

for k=1:numel(info.RawPackets)
    raw=uint8(info.RawPackets{k}(:).');
    if isempty(raw), continue; end
    if all(raw==uint8(255))
        emptyCount=emptyCount+1;
        continue
    end
    if raw(1)~=uint8(150), continue; end  % flash packet 0x96

    if numel(raw)<6 || raw(6)~=0
        error('Flash packet %d has a short header or encoder data.',k);
    end
    frameMask=localUInt32LE(raw,2);
    if flashCount==0
        expectedMask=frameMask;
        selected=find(bitand(frameMask,masks)==masks);
        remaining=frameMask;
        for j=selected
            remaining=bitxor(remaining,masks(j));
        end
        if isempty(selected) || remaining~=0
            error('Unknown/partial sensor mask: 0x%s.',dec2hex(frameMask,8));
        end
        nChannels=sum(widths(selected));
        X=zeros(0,nChannels);
    elseif frameMask~=expectedMask
        error('Flash packet %d has a different sensor mask.',k);
    end

    payload=raw(7:end);
    bytesPerSample=4*nChannels;
    if isempty(payload) || mod(numel(payload),bytesPerSample)~=0
        error('Flash packet %d has invalid payload size %d.',k,numel(payload));
    end
    values=typecast(payload,'single');
    [~,~,endianness]=computer;
    if endianness~='L'
        values=swapbytes(values);
    end
    block=reshape(double(values),nChannels,[]).';
    X=[X;block]; %#ok<AGROW>
    flashCount=flashCount+1;
    samplesPerPacket(end+1,1)=size(block,1); %#ok<AGROW>
end

if flashCount==0
    error('No standard-sensor flash packets (0x96) were found.');
end
if any(~isfinite(X(:)))
    warning('PocketLab:NonfiniteMemorySamples', ...
        'Some decoded sensor values are nonfinite.');
end

data=struct();
columns=0;
for j=selected
    n=widths(j);
    data.(names{j})=X(:,columns+(1:n));
    columns=columns+n;
end

% User-space metadata: 0x95, uint32 LE signature=1638, four uint32 words.
userWords=nan(1,4);
userTimeUTC=NaT;
userTimeUTC.TimeZone='UTC';
frequencyIndex=NaN;
frequencySource="Unresolved";
frequencyHz=NaN;
if isfield(info,'UserSpacePacket')
    u=uint8(info.UserSpacePacket(:).');
    if numel(u)>=21 && u(1)==uint8(149) && localUInt32LE(u,2)==1638
        for j=1:4
            userWords(j)=double(localUInt32LE(u,6+4*(j-1)));
        end
        frequencyIndex=userWords(3);
        nominalRates=[1/60 1/30 1/15 1/10 1/5 1 5 10 20 25 50 250];
        if frequencyIndex>=0 && frequencyIndex<numel(nominalRates) && ...
                frequencyIndex==floor(frequencyIndex)
            frequencyHz=nominalRates(frequencyIndex+1);
            frequencySource="User-space field 3 (inferred web-app rate index)";
        end
        if userWords(4)>0
            userTimeUTC=datetime(userWords(4),'ConvertFrom','posixtime','TimeZone','UTC');
        end
    end
end

if isfinite(rateOverride)
    frequencyHz=rateOverride;
    frequencySource="User-provided FrequencyHz override";
end

N=size(X,1);
if isfinite(frequencyHz)
    t=(0:N-1).'/frequencyHz;
else
    t=nan(N,1);
    warning('PocketLab:UnknownMemoryRate', ...
        'No recognized nominal rate: t set to NaN; provide "FrequencyHz".');
end

meta=struct();
meta.SampleCount=N;
meta.FlashPacketCount=flashCount;
meta.FlashPaddingPacketCount=emptyCount;
meta.SamplesPerFlashPacket=unique(samplesPerPacket).';
meta.ConfigurationMask=expectedMask;
meta.ChannelNames=labelNames(1:0);
for j=selected
    switch names{j}
        case {'acceleration','gyroscope','magnetometer'}
            switch names{j}
                case 'acceleration', labels={'acc_x','acc_y','acc_z'};
                case 'gyroscope', labels={'gyro_x','gyro_y','gyro_z'};
                otherwise, labels={'mag_x','mag_y','mag_z'};
            end
        case 'quaternion', labels={'q1','q2','q3','q4'};
        otherwise, labels=names(j);
    end
    meta.ChannelNames=[meta.ChannelNames labels]; %#ok<AGROW>
end
meta.NominalFrequencyHz=frequencyHz;
meta.FrequencySource=frequencySource;
meta.FrequencyIndexFromUserSpace=frequencyIndex;
meta.UserSpaceWords=userWords;
meta.UserSpaceTimeUTC=userTimeUTC;
meta.UserSpaceTimeInterpretation="Possible app-supplied recording time; origin unverified";
meta.SampleTimesAreNominal=true;
meta.HardwareSampleTimestampsVerified=false;
if isfinite(frequencyHz)
    meta.NominalRecordDuration_s=N/frequencyHz;
else
    meta.NominalRecordDuration_s=NaN;
end
if isfield(data,'quaternion')
    qnorm=sqrt(sum(data.quaternion.^2,2));
    meta.QuaternionNormMean=mean(qnorm);
end
end

function value=localUInt32LE(bytes,startIndex)
b=uint32(bytes(startIndex:startIndex+3));
value=b(1)+bitshift(b(2),8)+bitshift(b(3),16)+bitshift(b(4),24);
end
