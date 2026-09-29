function [t,A,info] = pocketlabAccel(recordTime,Fs,varargin)
%POCKETLABACCEL Convenience wrapper for pocketlabRead("acceleration",...).
[t,A,info] = pocketlabRead("acceleration",recordTime,Fs,varargin{:});
end
