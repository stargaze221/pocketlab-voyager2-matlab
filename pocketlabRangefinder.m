function [t,R,info] = pocketlabRangefinder(recordTime,Fs,varargin)
%POCKETLABRANGEFINDER Experimental convenience wrapper for rangefinder data.
[t,R,info] = pocketlabRead("rangefinder",recordTime,Fs,varargin{:});
end
