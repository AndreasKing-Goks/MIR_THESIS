function Obj_Val = Objective_Function(Estimation_Var, opt_weights, scales, dt, stop_time, accFunargs)
global Param
%% Get the measured data
% Velo mea should span over all the time steps.
% Thus extract the data directly
temp_Velo_Mea = squeeze(Param.NIF_nu_b).';
% Velo_Mea = temp_Velo_Mea(:, data);
Velo_Mea = temp_Velo_Mea;

%% Get the estimation data
% Scales back Estimation_Var_Scaled to Estimation_Var
Estimation_Var = Estimation_Var .* scales;

% Get the optimization variables
Param.NIF_AM = Estimation_Var(1:6);
Param.NIF_K_l = Estimation_Var(7:12);
Param.NIF_K_nl = Estimation_Var(13:18);
Param.NIF_Ballast_Force = [0 ; 0; Estimation_Var(19:21)'; 0];

% Get the estimated velocity
[~, nu_b] = BlueROV2_Dynamic_Model(dt, stop_time, accFunargs);
% Velo_Est = nu_b(:, data);
Velo_Est = nu_b;

%% Convergence coefficient
G_delta = 100;

%% Estimation-Measurement Error
delta = Velo_Est - Velo_Mea;

%% Compute cost value
% Get the velocity matrix size
[~, column_length] = size(delta);

% Comput the nominator and denuminator
nominator = zeros(1, column_length);
denuminator = zeros(1, column_length);
for column = 1 : column_length
    nominator(1, column) = delta(:, column)' * delta(:, column);
    denuminator(1, column) = Velo_Mea(:, column)' * Velo_Mea(:, column);
end

% Sum-weighted nominator
sum_weight_nominator = opt_weights * nominator';
sum_denuminator = sum(denuminator);

% Compute the objective value
Obj_Val = (sum_weight_nominator / sum_denuminator) * G_delta;

%% Handle exploding objective value
if Obj_Val > 100000
    Obj_Val = 100000;
end

end