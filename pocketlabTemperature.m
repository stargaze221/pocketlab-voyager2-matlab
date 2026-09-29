function [t,T,info] = pocketlabTemperature(recordTime,Fs,varargin)
%POCKETLABTEMPERATURE Experimental convenience wrapper for temperature data.
[t,T,info] = pocketlabRead("temperature",recordTime,Fs,varargin{:});
end
