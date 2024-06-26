function [Acc_G] = BlueROV2_acc(Ballast_Force, Thruster_Force, Tether_Force, Pos_N, Velo_B)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% BlueROV2_acc()                                                          %
%                                                                         %
% Compute the dynamics of the BlueROV2 given the external forces,         %
% position and velocity described at the body frame                       %
%                                                                         %
% Argument:                                                               %
% Ex_Force  : External forces directed at sphere, described on Body Frame %
% Pos_N     : Position described at NED frame. Dim(3x1).                  %
% Velo_B    : Velocity described at Body frame. Dim(3x1).                 %
%                                                                         %
% Output:                                                                 %
% Acc_G     : Total acceleration of the BlueROV2                          %
% Reference:                                                              %
% [9]  An Open-Source Benchmark Simulator: Control of a BlueROV2          %
%      Underwater Robot                                                   %
%                                                                         %
% Created:      13.02.2024	Andreas Sitorus                               %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
global Param
%% Position
% Described in NED frame
x = Pos_N(1,1);
y = Pos_N(2,1);
z = Pos_N(3,1);
phi = Pos_N(4,1);
theta = Pos_N(5,1);
psi = Pos_N(6,1);

% General Vector
T_ = [x; y; z];         % Translational Vector
R_ = [phi, theta, psi]; % Rotational Vector

%% Velocity
% Described in Body Frame at CO
u = Velo_B(1,1);
v = Velo_B(2,1);
w = Velo_B(3,1);
p = Velo_B(4,1);
q = Velo_B(5,1);
r = Velo_B(6,1);

% General Vector
V_ = [u; v; w];                 % Translation Velocity vector, read "Nu"
W_ = [p; q; r];                 % Angular velocity vector, read "Omega"

V_t = [V_ ; W_];                % 6DOF Velocity, expressed in CO

V_t_g = H_(-Param.CG.rg_o) * V_t;  % 6DOF Velocity, expressed in CG
V_t_b = H_(-Param.CB.rb_o) * V_t;  % 6DOF Velocity, expressed in CB

% Notes:
% For a velocity obtained from DVL, velocity is measured ad DVL Position.
% For damping and added mass coriolis-centripetal forces, transform the 
% velocity from DVL to CB. rCB_b = rCB_o - rb_o. Use rCB_b for H_ matrix

%% Centers
% Origin
xo = Param.CO.ro(1);
yo = Param.CO.ro(2);
zo = Param.CO.ro(3);

% Gravity
xg = Param.CG.rg(1);
yg = Param.CG.rg(2);
zg = Param.CG.rg(3);

% Buoyancy
xb = Param.CB.rb(1);
yb = Param.CB.rb(2);
zb = Param.CB.rb(3);

%% Restoring Forces
% Described in Body Frame, at Center of Gravity. ALREADY FOR THE LEFT HAND
% SIDE
Param.Fr_o = [(Param.W - Param.B)*sin(theta);
              -(Param.W - Param.B)*cos(theta)*sin(phi);
              -(Param.W - Param.B)*cos(theta)*cos(phi);
              -(yg*Param.W - yb*Param.B)*cos(theta)*cos(phi) + (zg*Param.W - zb*Param.B)*cos(theta)*sin(phi);
              (zg*Param.W - zb*Param.B)*sin(theta) + (xg*Param.W - xb*Param.B)*cos(theta)*cos(phi);
              -(xg*Param.W - xb*Param.B)*cos(theta)*sin(phi) - (yg*Param.W - yb*Param.B)*sin(theta)];

%% Coriolis-Centripetal Forces
% MOI
Ixx = Param.MOI(1);
Iyy = Param.MOI(2);
Izz = Param.MOI(3);

% Get CoG-body velocity
u_cg = V_t_g(1,1);
v_cg = V_t_g(2,1);
w_cg = V_t_g(3,1);
p_cg = V_t_g(4,1);
q_cg = V_t_g(5,1);
r_cg = V_t_g(6,1);

% CC-Rigid Body
% Described in Body frame, at Center of Gravity
Crb11 = zeros(3); 
Crb12 = [0 Param.m*w_cg -Param.m*v_cg;
         -Param.m*w_cg 0 Param.m*u_cg;
         Param.m*v_cg -Param.m*u_cg 0];
Crb21 = Crb12;
Crb22 = [0 -Izz*r_cg -Iyy*q_cg;
         Izz*r_cg 0 Ixx*p_cg;
         Iyy*q_cg -Ixx*p_cg 0];

Param.Crb = [Crb11 Crb12;
             Crb21 Crb22]; % Rigid Body Coriolis Force Matrix, at Center of Gravity
Param.Crb_o = (H_(Param.CG.rg_o))' * Param.Crb * V_t_g;

% Added Mass Coefficient
Xud = Param.AM(1);
Yvd = Param.AM(2);
Zwd = Param.AM(3);
Kpd = Param.AM(4);
Mqd = Param.AM(5);
Nrd = Param.AM(6);

% Get CoB-body velocity
u_cb = V_t_b(1,1);
v_cb = V_t_b(2,1);
w_cb = V_t_b(3,1);
p_cb = V_t_b(4,1);
q_cb = V_t_b(5,1);
r_cb = V_t_b(6,1);

% CC-Added Mass
% Described in Body frame, at Center of Buoyancy
Ca11 = zeros(3);
Ca12 = [0 -Zwd*w_cb Yvd*v_cb;
        Zwd*w_cb 0 -Xud*u_cb;
        -Yvd*v_cb Xud*u_cb 0];
Ca21 = Ca12;
Ca22 = [0 -Nrd*r_cb Mqd*q_cb;
        Nrd*r_cb 0 -Kpd*p_cb;
        -Mqd*q_cb Kpd*p_cb 0];

Param.Ca = [Ca11 Ca12;
            Ca21 Ca22]; % Added mass Coriolis Force Matrix, at Center of Buoyancy
Param.Ca_o = (H_(Param.CB.rb_o))' * Param.Ca * V_t_b;

% Total Coriolis-Centripetal Force
Param.Fc_o = (Param.Crb_o + Param.Ca_o);

%% Damping Forces
% Described in Body frame, at Center of Buoyancy
% All coefficients obtained from Experimentation [9]

% Linear Damping Forces 
Param.Fld_o = -(H_(Param.CB.rb_o))' * Param.K_l * _V_t_b;

% Non-Linear Damping Forces
NL_Damping_Coeff = diag(Param.K_nl) * abs(V_t_b);
Param.Fnld_o = -(H_(Param.CB.rb_o))' * diag(NL_Damping_Coeff) * V_t_b;

% Total Damping Forces
Param.Fd_o = Param.Fld_o + Param.Fnld_o; 

%% Ballast Term (Floater/Weight)
Param.g0 = Ballast_Force;

%% Thruster Term
Param.Ft = Thruster_Force;

%% Tether Term
Param.Ftet = Tether_Force;

%% Acceleration Computation 
Acc_G = Param.inv_MT * (Param.Ft + Param.Ftet - Param.Fc_o - Param.Fd_o + Param.Fr_o + Param.g0);
end