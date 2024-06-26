function [Result] = Convert2_Thrust_PWM(val_desired, voltage_desired, mode)
%% IN KG.Force
%% Add Path
% Current dir
currentDir = fileparts(mfilename('fullpath'));

% Add the 'T200_Data' path
T200_Data_Path = fullfile(currentDir, 'T200_Data');
addpath(T200_Data_Path);

%% Load All Thruster Data
% Gravitational acceleration
g = 9.81; 

% Container
thrust = [];
pwm = [];

% Create Bracket
voltage_levels = [10 12 14 16 18 20];

upper_vals = voltage_levels(voltage_desired <= voltage_levels);
lower_vals = voltage_levels(voltage_desired >= voltage_levels);

bracket = [lower_vals(end) upper_vals(1)];

% Go through data structures
load(fullfile(T200_Data_Path, 'thruster_data.mat'));
all_voltages = fieldnames(thruster_data);

for vol_num = 1 : numel(all_voltages)
    fieldname = sprintf(all_voltages{vol_num});

    thrust_v = thruster_data.(fieldname).data(:,6);
    pwm_v = thruster_data.(fieldname).data(:,1);

    thrust = [thrust thrust_v];
    pwm = [pwm pwm_v];
end

%% Interpolate Data
% Store interpolated value from every voltage
val_storage = [];

for i = 1: length(voltage_levels) % Go through each operating voltage
    val_voltage = Convert_Thrust_PWM(val_desired,voltage_levels(i),mode);
    val_storage = [val_storage val_voltage];
end

% Check if contain any NaN
contains_nan = any(isnan(val_storage));

if contains_nan
    % Find indices of NaN values
    nan_indices = find(isnan(val_storage));

    % Remove NaN
    valid_val = val_storage(~isnan(val_storage));
    valid_volt = voltage_levels(~isnan(val_storage));
else
    valid_val = val_storage;
    valid_volt = voltage_levels;
end

[unique_valid_val,idx] = unique(valid_val, 'stable');
unique_valid_volt = valid_volt(idx);

Result = interp1(unique_valid_volt,unique_valid_val, voltage_desired, 'linear') * g;
end