function [t,W,info] = pocketlabGyro(recordTime,Fs,varargin)
%POCKETLABGYRO Experimental convenience wrapper for gyroscope data.
[t,W,info] = pocketlabRead("gyroscope",recordTime,Fs,varargin{:});
end
