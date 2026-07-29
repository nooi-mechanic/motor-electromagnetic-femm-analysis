%% generate_v_ipm_motor.m
% Self-contained V-IPM FEMM generator script for Windows MATLAB.
% This version prioritizes compatibility with FEMM's group rotation API.
% Theta sweep is disabled by default so we can first verify model generation.

ensure_femm_path();

openfemm(1);
newdocument(0);
depth = 150;
mi_probdef(0, 'millimeters', 'planar', 1E-8, depth, 30, 0);

% Inconel 718 material
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

PM = 'N35';
Core = 'M-19 Steel';
Coil = '18 AWG';
Coilname = {'Coil_A', 'Coil_B', 'Coil_C'};

mi_getmaterial('Air');
mi_getmaterial(PM);
mi_getmaterial(Coil);
mi_getmaterial(Core);

PM_r = 53 / 2;
Seal = 5;
Core_ri = 64 / 2;
Core_ro = 150 / 2;
Slot_l = 20;
turns = 200;
max_segment = 10;
Core_angle = 5;
num_slots = 36;
Teeth_angle = pi / 66.95;
Teeth_length = 1;
Teeth_length2 = 1;
Arc_offset = 0.01 * pi;

shaft_r = 8;
magnet_length = 15;
magnet_thickness = 4;
v_angle_deg = 45;
magnet_center_r = PM_r - 6;
magnet_center_offset_deg = 20;
rotor_mech_angle_deg = -10;

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_theta5deg_comm23');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

run_theta_sweep = true;
theta_deg_vals = 0:5:355;
Imax = 10;
pole_pairs = 2;
commutation_offset_deg = 23;

% Rotor outer ring
mi_drawarc(PM_r + Seal, 0, -PM_r - Seal, 0, 180, max_segment);
mi_drawarc(-PM_r - Seal, 0, PM_r + Seal, 0, 180, max_segment);

% Shaft
mi_drawarc(shaft_r, 0, -shaft_r, 0, 180, max_segment);
mi_addarc(-shaft_r, 0, shaft_r, 0, 180, max_segment);

% V-shaped magnets
pole_axes_deg = [0, 90, 180, 270];
magnet_specs = [];

for pole_idx = 1:numel(pole_axes_deg)
    pole_axis_deg = pole_axes_deg(pole_idx) + rotor_mech_angle_deg;
    if mod(pole_idx, 2) == 1
        pole_magnetization_deg = mod(pole_axis_deg, 360);
    else
        pole_magnetization_deg = mod(pole_axis_deg + 180, 360);
    end

    magnet_specs = [
        magnet_specs;
        pole_axis_deg + magnet_center_offset_deg, magnet_center_r, pole_axis_deg + v_angle_deg, pole_magnetization_deg;
        pole_axis_deg - magnet_center_offset_deg, magnet_center_r, pole_axis_deg - v_angle_deg, pole_magnetization_deg
    ];
end

for i = 1:size(magnet_specs, 1)
    center_angle_deg = magnet_specs(i, 1);
    center_r = magnet_specs(i, 2);
    body_angle_deg = magnet_specs(i, 3);
    magnetization_deg = magnet_specs(i, 4);

    angle_rad = deg2rad(center_angle_deg);
    body_rad = deg2rad(body_angle_deg);

    cx = center_r * cos(angle_rad);
    cy = center_r * sin(angle_rad);

    along_x = cos(body_rad);
    along_y = sin(body_rad);
    normal_x = -sin(body_rad);
    normal_y = cos(body_rad);

    half_length = magnet_length / 2;
    half_thickness = magnet_thickness / 2;

    p1x = cx + along_x * half_length + normal_x * half_thickness;
    p1y = cy + along_y * half_length + normal_y * half_thickness;
    p2x = cx + along_x * half_length - normal_x * half_thickness;
    p2y = cy + along_y * half_length - normal_y * half_thickness;
    p3x = cx - along_x * half_length - normal_x * half_thickness;
    p3y = cy - along_y * half_length - normal_y * half_thickness;
    p4x = cx - along_x * half_length + normal_x * half_thickness;
    p4y = cy - along_y * half_length + normal_y * half_thickness;

    mi_drawline(p1x, p1y, p2x, p2y);
    mi_drawline(p2x, p2y, p3x, p3y);
    mi_drawline(p3x, p3y, p4x, p4y);
    mi_drawline(p4x, p4y, p1x, p1y);

    mi_addblocklabel(cx, cy);
    mi_selectlabel(cx, cy);
    mi_setblockprop(PM, 1, 0, 0, magnetization_deg, 1, 0);
    mi_clearselected;
end

mi_addblocklabel(0, shaft_r + 1);
mi_selectlabel(0, shaft_r + 1);
mi_setblockprop(Core, 1, 0, 0, 0, 1, 0);
mi_clearselected;

mi_addblocklabel(0, 0);
mi_selectlabel(0, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
mi_clearselected;

% Group rotor geometry for compatible rotation calls
mi_selectcircle(0, 0, PM_r + Seal + 1, 4);
mi_setgroup(1);
mi_clearselected;

% Stator outer ring
mi_drawarc(Core_ro, 0, -Core_ro, 0, 180, max_segment);
mi_addarc(-Core_ro, 0, Core_ro, 0, 180, max_segment);

% Slots and teeth
for i = 0:num_slots
    h = (i - 1) * 2 * pi / 180;
    j = i * 2 * pi / 180;
    k = (i + 1) * 2 * pi / 180;
    L = (i + 2) * 2 * pi / 180;
    if mod(i, 2) == 1
        mi_drawarc(Core_ri * cos(h * Core_angle - Teeth_angle), Core_ri * sin(h * Core_angle - Teeth_angle), Core_ri * cos(j * Core_angle + Teeth_angle), Core_ri * sin(j * Core_angle + Teeth_angle), Core_angle + Teeth_angle * 2, max_segment);
        mi_drawline(Core_ri * cos(h * Core_angle - Teeth_angle), Core_ri * sin(h * Core_angle - Teeth_angle), (Core_ri + Teeth_length) * cos(h * Core_angle - Teeth_angle), (Core_ri + Teeth_length) * sin(h * Core_angle - Teeth_angle));
        mi_drawline(Core_ri * cos(j * Core_angle + Teeth_angle), Core_ri * sin(j * Core_angle + Teeth_angle), (Core_ri + Teeth_length) * cos(j * Core_angle + Teeth_angle), (Core_ri + Teeth_length) * sin(j * Core_angle + Teeth_angle));
        mi_drawline((Core_ri + Teeth_length) * cos(h * Core_angle - Teeth_angle), (Core_ri + Teeth_length) * sin(h * Core_angle - Teeth_angle), (Core_ri + Teeth_length + Teeth_length2) * cos(h * Core_angle), (Core_ri + Teeth_length + Teeth_length2) * sin(h * Core_angle));
        mi_drawline((Core_ri + Teeth_length) * cos(j * Core_angle + Teeth_angle), (Core_ri + Teeth_length) * sin(j * Core_angle + Teeth_angle), (Core_ri + Teeth_length + Teeth_length2) * cos(j * Core_angle), (Core_ri + Teeth_length + Teeth_length2) * sin(j * Core_angle));
        mi_drawline((Core_ri + Teeth_length + Teeth_length2) * cos(j * Core_angle), (Core_ri + Teeth_length + Teeth_length2) * sin(j * Core_angle), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * cos(j * Core_angle - Arc_offset), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * sin(j * Core_angle - Arc_offset));
    else
        mi_drawarc((Core_ri + Teeth_length + Teeth_length2 + Slot_l) * cos(k * Core_angle - Arc_offset), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * sin(k * Core_angle - Arc_offset), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * cos(L * Core_angle + Arc_offset), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * sin(L * Core_angle + Arc_offset), 180, max_segment);
        mi_drawarc(Core_ri * cos(h * Core_angle + Teeth_angle), Core_ri * sin(h * Core_angle + Teeth_angle), Core_ri * cos(j * Core_angle - Teeth_angle), Core_ri * sin(j * Core_angle - Teeth_angle), Core_angle - Teeth_angle * 2, max_segment);
        mi_drawline((Core_ri + Teeth_length + Teeth_length2) * cos(j * Core_angle), (Core_ri + Teeth_length + Teeth_length2) * sin(j * Core_angle), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * cos(j * Core_angle + Arc_offset), (Core_ri + Teeth_length + Teeth_length2 + Slot_l) * sin(j * Core_angle + Arc_offset));
    end
end

stator_backiron_r = (Core_ro + (Core_ri + Teeth_length + Teeth_length2 + Slot_l)) / 2;
mi_addblocklabel(stator_backiron_r, 0);
mi_selectlabel(stator_backiron_r, 0);
mi_setblockprop(Core, 1, 0, 0, 0, 2, 0);
mi_clearselected;

mi_addblocklabel((PM_r + Seal + Core_ri) / 2, 0);
mi_selectlabel((PM_r + Seal + Core_ri) / 2, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
mi_clearselected;

mi_addblocklabel(PM_r * 5, 0);
mi_selectlabel(PM_r * 5, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
mi_clearselected;

% Coil winding labels for 18-slot / 4-pole / 3-phase layout.
% Slot centers are at 15, 35, ..., 355 mechanical degrees.
% Winding pattern:
%   AAA B'B'B' CCC A'A'A' BBB C'C'C'
% so the A-phase axis is centered at 125 mechanical degrees.
slot_center_deg = 15:20:355;
slot_label_radius = (Core_ri + Teeth_length2 + Slot_l) * cosd(5);
slot_circuit_names = { ...
    Coilname{1}, Coilname{1}, Coilname{1}, ...
    Coilname{2}, Coilname{2}, Coilname{2}, ...
    Coilname{3}, Coilname{3}, Coilname{3}, ...
    Coilname{1}, Coilname{1}, Coilname{1}, ...
    Coilname{2}, Coilname{2}, Coilname{2}, ...
    Coilname{3}, Coilname{3}, Coilname{3}};
slot_turn_signs = [ ...
     turns,  turns,  turns, ...
    -turns, -turns, -turns, ...
     turns,  turns,  turns, ...
    -turns, -turns, -turns, ...
     turns,  turns,  turns, ...
    -turns, -turns, -turns];

for i = 1:numel(Coilname)
    mi_addcircprop(Coilname{i}, 0, 1);
end

for slot_idx = 1:numel(slot_center_deg)
    angle_deg = slot_center_deg(slot_idx);
    x = slot_label_radius * cosd(angle_deg);
    y = slot_label_radius * sind(angle_deg);
    mi_addblocklabel(x, y);
    mi_selectlabel(x, y);
    mi_setblockprop(Coil, 1, 0, slot_circuit_names{slot_idx}, 0, 2, slot_turn_signs(slot_idx));
    mi_clearselected;
end

mi_makeABC(7, Core_ro * 2, 0, 0, 0);
base_fem_filename = fullfile(output_dir, 'v_ipm_motor_base.fem');
mi_saveas(base_fem_filename);

disp(['Saved base FEMM model to: ' base_fem_filename]);

if run_theta_sweep
    torque = zeros(size(theta_deg_vals));
    F_x = zeros(size(theta_deg_vals));
    F_y = zeros(size(theta_deg_vals));
    Ia_hist = zeros(size(theta_deg_vals));
    Ib_hist = zeros(size(theta_deg_vals));
    Ic_hist = zeros(size(theta_deg_vals));

    for theta_idx = 1:numel(theta_deg_vals)
        theta_deg = theta_deg_vals(theta_idx);
        fem_filename = fullfile(output_dir, sprintf('v_ipm_motor_%03ddeg.fem', theta_deg));

        opendocument(base_fem_filename);

        mi_selectgroup(1);
        mi_moverotate(0, 0, theta_deg);
        mi_clearselected;

        theta_elec_rad = deg2rad(pole_pairs * (theta_deg + commutation_offset_deg));
        Ia = -Imax * sin(theta_elec_rad);
        Ib = -Imax * sin(theta_elec_rad - 2 * pi / 3);
        Ic = -Imax * sin(theta_elec_rad + 2 * pi / 3);

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
        mo_close;
        mi_close;
    end

    save(fullfile(output_dir, 'v_ipm_theta_sweep.mat'), ...
        'theta_deg_vals', 'torque', 'F_x', 'F_y', ...
        'Ia_hist', 'Ib_hist', 'Ic_hist', 'Imax', 'pole_pairs');
end

function ensure_femm_path()
    femm_mfiles = 'C:\femm42\mfiles';
    if exist('openfemm', 'file') ~= 2
        addpath(femm_mfiles);
    end
    if exist('openfemm', 'file') ~= 2
        error('Could not find openfemm.m. Expected FEMM mfiles at C:\femm42\mfiles');
    end
end
