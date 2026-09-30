%% PocketLab Voyager 2 - MATLAB Demo
% Pair once before using:
%   pocketlabPair

clear
close all
clc

recordTime = 10;
Fs = 20;

%% Verified accelerometer example
[t,A,info] = pocketlabRead("acceleration",recordTime,Fs);

figure
plot(t,A,'LineWidth',1.1)
xlabel('Time [s]')
ylabel('Acceleration [g]')
legend('a_x','a_y','a_z','Location','best')
title('PocketLab Voyager 2 Accelerometer')
grid on

fprintf('Mean |a| = %.4f g\n',mean(vecnorm(A,2,2)));
disp(info)

%% Other sensor examples (experimental until physically validated)
% [t,W] = pocketlabRead("gyroscope",10,20);
% [t,R] = pocketlabRead("rangefinder",10,20);
% [t,T] = pocketlabRead("temperature",30,1);
% [t,P] = pocketlabRead("pressure",30,1);
