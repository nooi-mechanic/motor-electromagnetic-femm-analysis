%% ========================= FEMM SPM Modeling ============================
clc, clear

% Material definitions
PM = 'SmCo17_Grade17';
Core = 'SiSteel';
Sealing = 'Inconel 718';
Coil = '18 AWG';
Coilname = {'Coil_A','Coil_B','Coil_C'};

% Geometry parameters
depth = 150;
PM_r = 53 / 2;
Seal = 5;
stator_inner_radius = 64 / 2;
stator_outer_radius = 150 / 2;
slot_length = 20;
turns = 200;
max_segment = 10;
slot_pitch_deg = 5;
num_slots = 36;
tooth_half_angle = pi / 66.95;
tooth_length_inner = 1;
tooth_length_outer = 1;
arc_offset = 0.01 * pi;

tooth_tip_radius = stator_inner_radius + tooth_length_inner;
tooth_shoulder_radius = tooth_tip_radius + tooth_length_outer;
slot_outer_radius = tooth_shoulder_radius + slot_length;
outer_pm_radius = PM_r + Seal;

% Output folder
output_dir = fullfile(pwd, 'femm_output_spm');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% FEMM setting
openfemm(1);
newdocument(0);
mi_probdef(0,'millimeters','planar',1E-8,depth,30,0);

% Core material
mi_addmaterial(Core, 4000, 4000, 0, 1.8e6, 0.0, 0.35, 1.5, 0.95, 0, 0, 0, 0, 0);
core_bh = [
  0,     0.000;
  100,   0.005;
  500,   0.050;
  1000,  0.150;
  2000,  0.300;
  3000,  0.450;
  5000,  0.700;
  8000,  1.000;
  12000, 1.250;
  16000, 1.400;
  20000, 1.450;
  25000, 1.470;
  30000, 1.480;
  35000, 1.490;
  40000, 1.500
];
for idx = 1:size(core_bh, 1)
    mi_addbhpoint(Core, core_bh(idx,2), core_bh(idx,1));
end

% Magnet material
mi_addmaterial(PM, 1.0, 1.05, 0, -750e3, 6.7e5);
pm_bh = [
  0,       0.00;
  20e3,    0.10;
  100e3,   0.30;
  300e3,   0.60;
  500e3,   0.78;
  650e3,   0.87;
  750e3,   0.95;
  850e3,   1.00;
  950e3,   1.03;
  1100e3,  1.05;
  1300e3,  1.07;
  1500e3,  1.08
];
for idx = 1:size(pm_bh, 1)
    mi_addbhpoint(PM, pm_bh(idx,2), pm_bh(idx,1));
end

% Sealing material
mi_addmaterial(Sealing, ...
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

% Get materials
mi_getmaterial('Air');
mi_getmaterial(Coil);

% Rotor arcs
mi_drawarc(PM_r,0,-PM_r,0,180,max_segment);
mi_selectarcsegment(0,PM_r);
mi_setarcsegmentprop(max_segment,'None',0,1);
mi_clearselected;

mi_addarc(-PM_r,0,PM_r,0,180,max_segment);
mi_selectarcsegment(0,-PM_r);
mi_setarcsegmentprop(max_segment,'None',0,1);
mi_clearselected;

mi_drawarc(outer_pm_radius,0,-outer_pm_radius,0,180,max_segment);
mi_selectarcsegment(0,PM_r + Seal / 2);
mi_setarcsegmentprop(max_segment,'None',0,1);
mi_clearselected;

mi_drawarc(-outer_pm_radius,0,outer_pm_radius,0,180,max_segment);
mi_selectarcsegment(0,-PM_r - Seal / 2);
mi_setarcsegmentprop(max_segment,'None',0,1);
mi_clearselected;

% Rotor and sealing labels
mi_addblocklabel(0,0);
mi_selectlabel(0,0);
mi_setblockprop(PM,1,0,0,90,1,0);
mi_clearselected;

mi_addblocklabel(0,PM_r + Seal / 2);
mi_selectlabel(0,PM_r + Seal / 2);
mi_setblockprop(Sealing,1,0,0,90,1,0);
mi_clearselected;

% Stator outer boundary
mi_drawarc(stator_outer_radius,0,-stator_outer_radius,0,180,max_segment);
mi_addarc(-stator_outer_radius,0,stator_outer_radius,0,180,max_segment);

% Teeth and slot opening geometry
for slot_idx = 0:(num_slots - 1)
    prev_angle = deg2rad((slot_idx - 1) * slot_pitch_deg);
    curr_angle = deg2rad(slot_idx * slot_pitch_deg);
    next_angle = deg2rad((slot_idx + 1) * slot_pitch_deg);
    next_next_angle = deg2rad((slot_idx + 2) * slot_pitch_deg);

    if mod(slot_idx, 2) == 1
        p1x = stator_inner_radius * cos(prev_angle - tooth_half_angle);
        p1y = stator_inner_radius * sin(prev_angle - tooth_half_angle);
        p2x = stator_inner_radius * cos(curr_angle + tooth_half_angle);
        p2y = stator_inner_radius * sin(curr_angle + tooth_half_angle);
        p3x = tooth_tip_radius * cos(prev_angle - tooth_half_angle);
        p3y = tooth_tip_radius * sin(prev_angle - tooth_half_angle);
        p4x = tooth_tip_radius * cos(curr_angle + tooth_half_angle);
        p4y = tooth_tip_radius * sin(curr_angle + tooth_half_angle);
        p5x = tooth_shoulder_radius * cos(prev_angle);
        p5y = tooth_shoulder_radius * sin(prev_angle);
        p6x = tooth_shoulder_radius * cos(curr_angle);
        p6y = tooth_shoulder_radius * sin(curr_angle);
        p7x = slot_outer_radius * cos(curr_angle - arc_offset);
        p7y = slot_outer_radius * sin(curr_angle - arc_offset);

        mi_drawarc(p1x,p1y,p2x,p2y,slot_pitch_deg + rad2deg(2 * tooth_half_angle),max_segment);
        mi_drawline(p1x,p1y,p3x,p3y);
        mi_drawline(p2x,p2y,p4x,p4y);
        mi_drawline(p3x,p3y,p5x,p5y);
        mi_drawline(p4x,p4y,p6x,p6y);
        mi_drawline(p6x,p6y,p7x,p7y);
    else
        p1x = slot_outer_radius * cos(next_angle - arc_offset);
        p1y = slot_outer_radius * sin(next_angle - arc_offset);
        p2x = slot_outer_radius * cos(next_next_angle + arc_offset);
        p2y = slot_outer_radius * sin(next_next_angle + arc_offset);
        p3x = stator_inner_radius * cos(prev_angle + tooth_half_angle);
        p3y = stator_inner_radius * sin(prev_angle + tooth_half_angle);
        p4x = stator_inner_radius * cos(curr_angle - tooth_half_angle);
        p4y = stator_inner_radius * sin(curr_angle - tooth_half_angle);
        p5x = tooth_shoulder_radius * cos(curr_angle);
        p5y = tooth_shoulder_radius * sin(curr_angle);
        p6x = slot_outer_radius * cos(curr_angle + arc_offset);
        p6y = slot_outer_radius * sin(curr_angle + arc_offset);

        mi_drawarc(p1x,p1y,p2x,p2y,180,max_segment);
        mi_drawarc(p3x,p3y,p4x,p4y,slot_pitch_deg - rad2deg(2 * tooth_half_angle),max_segment);
        mi_drawline(p5x,p5y,p6x,p6y);
    end
end

% Stator and air labels
mi_addblocklabel(stator_outer_radius - 0.1,0);
mi_selectlabel(stator_outer_radius - 0.1,0);
mi_setblockprop(Core,1,0,0,0,2,0);
mi_clearselected;

mi_addblocklabel((outer_pm_radius + stator_inner_radius) / 2,0);
mi_selectlabel((outer_pm_radius + stator_inner_radius) / 2,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;

mi_addblocklabel(PM_r * 5,0);
mi_selectlabel(PM_r * 5,0);
mi_setblockprop('Air',1,0,0,0,2,0);
mi_clearselected;

% Distributed winding labels
coil_radius = slot_outer_radius;
coil_phase_offsets = [-pi / 3, 0, pi / 3, 2 * pi / 3, pi, 4 * pi / 3];
coil_phase_names = {Coilname{3}, Coilname{1}, Coilname{2}, ...
                    Coilname{3}, Coilname{1}, Coilname{2}};
coil_turn_signs = [-1, 1, 1, 1, -1, -1];

for phase_idx = 1:numel(Coilname)
    mi_addcircprop(Coilname{phase_idx},0,1);
end

for sector_idx = 1:3
    base_left_angle = deg2rad((2 * sector_idx - 1) * slot_pitch_deg);
    base_right_angle = deg2rad((2 * sector_idx + 1) * slot_pitch_deg);

    for coil_idx = 1:numel(coil_phase_offsets)
        left_x = coil_radius * cos(base_left_angle + coil_phase_offsets(coil_idx));
        left_y = coil_radius * sin(base_left_angle + coil_phase_offsets(coil_idx));
        right_x = coil_radius * cos(base_right_angle + coil_phase_offsets(coil_idx));
        right_y = coil_radius * sin(base_right_angle + coil_phase_offsets(coil_idx));

        label_x = (left_x + right_x) / 2;
        label_y = (left_y + right_y) / 2;

        mi_addblocklabel(label_x,label_y);
        mi_selectlabel(label_x,label_y);
        mi_setblockprop(Coil,1,0,coil_phase_names{coil_idx},0,2,coil_turn_signs(coil_idx) * turns);
        mi_clearselected;
    end
end

% Boundary and save
mi_makeABC(7,PM_r * 20,0,0,0);
filename = fullfile(output_dir, 'spm.fem');
mi_saveas(filename);

% This file currently generates geometry only.
