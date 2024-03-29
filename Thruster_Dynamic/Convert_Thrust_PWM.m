function [Result] = Convert_Thrust_PWM(val_desired, voltage, mode)
%% Add Path
% Current dir
currentDir = fileparts(mfilename('fullpath'));

% Add the 'T200_Data' path
T200_Data_Path = fullfile(currentDir, 'T200_Data');
addpath(T200_Data_Path);

%% Load Data
load(fullfile(T200_Data_Path, 'thruster_data.mat'));
fieldname = sprintf('voltage_%d', voltage);

force = thruster_data.(fieldname).data(:,6);
pwm = thruster_data.(fieldname).data(:,1);

% Remove zero-thrust regions from data
[unique_force, idx] = unique(force, 'stable');
unique_pwm = pwm(idx);

%% Interpolate Data
% Switch Mode
% Force to PWM
if mode == 0
    PWM_est = interp1(unique_force, unique_pwm, val_desired, 'linear');
    Result = PWM_est;
% PWM to Force
elseif mode == 1
    Force_est = interp1(unique_pwm, unique_force, val_desired, 'linear');
    Result = Force_est;
end
end