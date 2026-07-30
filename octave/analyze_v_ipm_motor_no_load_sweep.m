%% analyze_v_ipm_motor_no_load_sweep.m - V-IPM no-load theta sweep
% 전류를 모두 0으로 둔 상태에서 로터를 1도씩 회전시키며 해석한다.
% 목적:
% 1. 무부하 자속/토크 리플 확인
% 2. 이후 부하 전류 커뮤테이션 위상 기준점 확인

clc;
clear;
tic;

theta_deg_vals = 0:1:359;
depth = 150;

output_dir = fullfile(pwd, 'femm_output_v_ipm_no_load_sweep');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

openfemm(1);

Coilname = {'Coil_A','Coil_B','Coil_C'};
torque = zeros(size(theta_deg_vals));
F_x = zeros(size(theta_deg_vals));
F_y = zeros(size(theta_deg_vals));
Ia_hist = zeros(size(theta_deg_vals));
Ib_hist = zeros(size(theta_deg_vals));
Ic_hist = zeros(size(theta_deg_vals));

for theta_idx = 1:numel(theta_deg_vals)
    theta_deg = theta_deg_vals(theta_idx);
    fem_filename = fullfile(output_dir, sprintf('v_ipm_motor_no_load_%03ddeg.fem', theta_deg));

    build_v_ipm_motor_case(theta_deg, depth, fem_filename);

    Ia = 0;
    Ib = 0;
    Ic = 0;

    Ia_hist(theta_idx) = Ia;
    Ib_hist(theta_idx) = Ib;
    Ic_hist(theta_idx) = Ic;

    mi_setcurrent(Coilname{1}, Ia);
    mi_setcurrent(Coilname{2}, Ib);
    mi_setcurrent(Coilname{3}, Ic);

    mi_saveas(fem_filename);
    mi_analyze;
    mi_loadsolution;

    mo_groupselectblock(1);
    torque(theta_idx) = mo_blockintegral(22);
    F_x(theta_idx) = mo_blockintegral(18);
    F_y(theta_idx) = mo_blockintegral(19);
    mo_clearblock;
end

save(fullfile(output_dir, 'v_ipm_no_load_theta_sweep.mat'), ...
    'theta_deg_vals', 'torque', 'F_x', 'F_y', 'Ia_hist', 'Ib_hist', 'Ic_hist');

figure(1);
subplot(3,1,1);
plot(theta_deg_vals, torque, 'b', 'LineWidth', 1);
grid on;
title('V-IPM No-Load Torque vs Mechanical Angle');
xlabel('\theta_{mech} [deg]');
ylabel('Torque');

subplot(3,1,2);
plot(theta_deg_vals, F_x, 'r', 'LineWidth', 1);
grid on;
title('V-IPM No-Load F_x vs Mechanical Angle');
xlabel('\theta_{mech} [deg]');
ylabel('F_x');

subplot(3,1,3);
plot(theta_deg_vals, F_y, 'k', 'LineWidth', 1);
grid on;
title('V-IPM No-Load F_y vs Mechanical Angle');
xlabel('\theta_{mech} [deg]');
ylabel('F_y');

toc;

function build_v_ipm_motor_case(rotor_mech_angle_deg, depth, fem_filename)
newdocument(0);
mi_probdef(0,'millimeters','planar',1E-8,depth,30,0);

% 규소강판(Silicon Steel) 코어 재료 정의
mi_addmaterial('SiSteel', 4000, 4000, 0, 1.8e6, 0.0, 0.35, 1.5, 0.95, 0, 0, 0, 0, 0);
bh_core = [
    0, 0;
    100, 0.005;
    500, 0.05;
    1000, 0.15;
    2000, 0.30;
    3000, 0.45;
    5000, 0.70;
    8000, 1.00;
    12000, 1.25;
    16000, 1.40;
    20000, 1.45;
    25000, 1.47;
    30000, 1.48;
    35000, 1.49;
    40000, 1.50
];
for i = 1:size(bh_core,1)
    mi_addbhpoint('SiSteel', bh_core(i,2), bh_core(i,1));
end

% Inconel 718 material 정의
mi_addmaterial('Inconel 718', ...
    1.02, ...
    1.02, ...
    0, ...
    0, ...
    0.8, ...
    0, ...
    0, ...
    1, ...
    0, ...
    0, ...
    0, ...
    1, ...
    0);

% 재료 정의
PM = 'N35';
Core = 'SiSteel';
Sealing = 'Inconel 718';
Coil = '18 AWG';
Coilname = {'Coil_A','Coil_B','Coil_C'};

% 재료 로딩
mi_getmaterial('Air');
mi_getmaterial(PM);
mi_getmaterial(Coil);

% 파라미터
PM_r = 53/2;
Seal = 5;
Core_ri = 64/2;
Core_ro = 150/2;
Slot_l = 20;
turns = 200;
max_segment = 10;
Core_angle = 5;
num_slots = 36;
Teeth_angle = pi/66.95;
Teeth_length = 1;
Teeth_length2 = 1;
Arc_offset = 0.01*pi;

% V형 IPM 로터 파라미터
shaft_r = 8;
magnet_length = 15;
magnet_thickness = 4;
v_angle_deg = 45;
magnet_center_r = PM_r - 6;
magnet_center_offset_deg = 20;

%% 회전자 (V-IPM)
mi_drawarc(PM_r+Seal,0,-PM_r-Seal,0,180,max_segment);
mi_drawarc(-PM_r-Seal,0,PM_r+Seal,0,180,max_segment);

mi_drawarc(shaft_r,0,-shaft_r,0,180,max_segment);
mi_addarc(-shaft_r,0,shaft_r,0,180,max_segment);

pole_axes_deg = [0, 90, 180, 270];
magnet_specs = [];

for pole_idx = 1:numel(pole_axes_deg)
    pole_axis_deg = pole_axes_deg(pole_idx) + rotor_mech_angle_deg;
    pole_magnetization_deg = mod(180 - pole_axis_deg, 360);

    magnet_specs = [
        magnet_specs;
        pole_axis_deg + magnet_center_offset_deg, magnet_center_r, pole_axis_deg + v_angle_deg, pole_magnetization_deg;
        pole_axis_deg - magnet_center_offset_deg, magnet_center_r, pole_axis_deg - v_angle_deg, pole_magnetization_deg
    ];
end

for i = 1:size(magnet_specs,1)
    center_angle_deg = magnet_specs(i,1);
    center_r = magnet_specs(i,2);
    body_angle_deg = magnet_specs(i,3);
    magnetization_deg = magnet_specs(i,4);

    angle_rad = deg2rad(center_angle_deg);
    body_rad = deg2rad(body_angle_deg);

    cx = center_r*cos(angle_rad);
    cy = center_r*sin(angle_rad);

    along_x = cos(body_rad);
    along_y = sin(body_rad);
    normal_x = -sin(body_rad);
    normal_y = cos(body_rad);

    half_length = magnet_length/2;
    half_thickness = magnet_thickness/2;

    p1x = cx + along_x*half_length + normal_x*half_thickness;
    p1y = cy + along_y*half_length + normal_y*half_thickness;
    p2x = cx + along_x*half_length - normal_x*half_thickness;
    p2y = cy + along_y*half_length - normal_y*half_thickness;
    p3x = cx - along_x*half_length - normal_x*half_thickness;
    p3y = cy - along_y*half_length - normal_y*half_thickness;
    p4x = cx - along_x*half_length + normal_x*half_thickness;
    p4y = cy - along_y*half_length + normal_y*half_thickness;

    mi_drawline(p1x,p1y,p2x,p2y);
    mi_drawline(p2x,p2y,p3x,p3y);
    mi_drawline(p3x,p3y,p4x,p4y);
    mi_drawline(p4x,p4y,p1x,p1y);

    mi_addblocklabel(cx,cy);
    mi_selectlabel(cx,cy);
    mi_setblockprop(PM,1,0,0,magnetization_deg,1,0);
    mi_clearselected;
end

mi_addblocklabel(0,shaft_r+5);
mi_selectlabel(0,shaft_r+5);
mi_setblockprop(Core,1,0,0,0,1,0);
mi_clearselected;

mi_addblocklabel(0,0);
mi_selectlabel(0,0);
mi_setblockprop('Air',1,0,0,0,1,0);
mi_clearselected;

%% 고정자 외곽
mi_drawarc(Core_ro,0,-Core_ro,0,180,max_segment);
mi_addarc(-Core_ro,0,Core_ro,0,180,max_segment);

%% 슬롯 및 이(Teeth)
for i = 0:num_slots
    h = (i-1)*2*pi/180;
    j = i*2*pi/180;
    k = (i+1)*2*pi/180;
    L = (i+2)*2*pi/180;
    if mod(i,2) == 1
        mi_drawarc(Core_ri*cos(h*Core_angle-Teeth_angle),Core_ri*sin(h*Core_angle-Teeth_angle),Core_ri*cos(j*Core_angle+Teeth_angle),Core_ri*sin(j*Core_angle+Teeth_angle),Core_angle+Teeth_angle*2,max_segment);
        mi_drawline(Core_ri*cos(h*Core_angle-Teeth_angle),Core_ri*sin(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*cos(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*sin(h*Core_angle-Teeth_angle));
        mi_drawline(Core_ri*cos(j*Core_angle+Teeth_angle),Core_ri*sin(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*cos(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*sin(j*Core_angle+Teeth_angle));
        mi_drawline((Core_ri+Teeth_length)*cos(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length)*sin(h*Core_angle-Teeth_angle),(Core_ri+Teeth_length+Teeth_length2)*cos(h*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(h*Core_angle));
        mi_drawline((Core_ri+Teeth_length)*cos(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length)*sin(j*Core_angle+Teeth_angle),(Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle));
        mi_drawline((Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(j*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(j*Core_angle-Arc_offset));
    else
        mi_drawarc((Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(k*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(k*Core_angle-Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(L*Core_angle+Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(L*Core_angle+Arc_offset),180,max_segment);
        mi_drawarc(Core_ri*cos(h*Core_angle+Teeth_angle),Core_ri*sin(h*Core_angle+Teeth_angle),Core_ri*cos(j*Core_angle-Teeth_angle),Core_ri*sin(j*Core_angle-Teeth_angle),Core_angle-Teeth_angle*2,max_segment);
        mi_drawline((Core_ri+Teeth_length+Teeth_length2)*cos(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2)*sin(j*Core_angle),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*cos(j*Core_angle+Arc_offset),(Core_ri+Teeth_length+Teeth_length2+Slot_l)*sin(j*Core_angle+Arc_offset));
    end
end

mi_addblocklabel(Core_ro-0.1,0);
mi_selectlabel(Core_ro-0.1,0);
mi_setblockprop(Core,1,0,0,0,2,0);
mi_clearselected;

mi_addblocklabel((PM_r+Seal+Core_ri)/2,0);
mi_selectlabel((PM_r+Seal+Core_ri)/2,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;

mi_addblocklabel(PM_r*5,0);
mi_selectlabel(PM_r*5,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;

%% Coil Winding
for i = 1:3
    h = (i-1)*2*pi/180;
    j = i*2*pi/180;
    k = (i+1)*2*pi/180;

    mi_addcircprop(Coilname{i},0,1);

    P = -3*pi/9;
    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
    mi_setblockprop(Coil,1,0,Coilname{3},0,2,-turns);
    mi_clearselected;

    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle))/2);
    mi_setblockprop(Coil,1,0,Coilname{1},0,2,turns);
    mi_clearselected;

    P = 3*pi/9;
    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+P))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+P)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+P))/2);
    mi_setblockprop(Coil,1,0,Coilname{2},0,2,turns);
    mi_clearselected;

    copy_angle = pi-P;
    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_setblockprop(Coil,1,0,Coilname{3},0,2,turns);
    mi_clearselected;

    copy_angle = pi;
    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_setblockprop(Coil,1,0,Coilname{1},0,2,-turns);
    mi_clearselected;

    copy_angle = pi+P;
    mi_addblocklabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_selectlabel(((Core_ri+Teeth_length2+Slot_l)*cos((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*cos((k+h)*Core_angle+copy_angle))/2,((Core_ri+Teeth_length2+Slot_l)*sin((j+h)*Core_angle+copy_angle)+(Core_ri+Teeth_length2+Slot_l)*sin((k+h)*Core_angle+copy_angle))/2);
    mi_setblockprop(Coil,1,0,Coilname{2},0,2,-turns);
    mi_clearselected;
end

mi_makeABC(7,PM_r*20,0,0,0);
mi_saveas(fem_filename);
end
