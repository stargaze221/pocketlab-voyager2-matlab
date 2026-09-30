function [t,P,info] = pocketlabPressure(recordTime,Fs,varargin)
%POCKETLABPRESSURE Experimental convenience wrapper for pressure data.
[t,P,info] = pocketlabRead("pressure",recordTime,Fs,varargin{:});
end
