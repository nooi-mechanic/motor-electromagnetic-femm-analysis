%% export_axis_shortedge_offset_compare_codex.m
% Export two single FEM previews with identical geometry except for
% magnet_center_offset_deg = 20 and 25.

ensure_femm_path_local();

base_settings = default_v_ipm_m19_settings_codex();
base_settings.magnet_length = 15.0;
base_settings.magnet_thickness = 4.0;
base_settings.v_angle_deg = 52.5; % included V angle = 105 deg

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_single_fem_axis_parallel_shortedge_offset_compare_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

offset_list_deg = [20, 25];

for idx = 1:numel(offset_list_deg)
    settings = base_settings;
    settings.magnet_center_offset_deg = offset_list_deg(idx);

    fem_filename = fullfile(output_dir, ...
        sprintf('single_axis_parallel_shortedge_offset_%02ddeg.fem', settings.magnet_center_offset_deg));

    openfemm(1);
    cleanup_femm = onCleanup(@() safe_close_femm_local()); %#ok<NASGU>

    newdocument(0);
    mi_probdef(0, 'millimeters', 'planar', 1E-8, settings.depth, 30, 0);
    build_motor_model_axis_parallel_shortedge(0, settings);
    mi_saveas(fem_filename);

    fprintf('Saved FEM preview to %s\n', fem_filename);
    clear cleanup_femm;
    safe_close_femm_local();
end

function build_motor_model_axis_parallel_shortedge(theta_deg, s)
rotor_mech_angle_deg = theta_deg + s.rotor_mech_angle_deg;

mi_getmaterial('Air');
mi_getmaterial(s.Coil);
mi_getmaterial(s.Core);
mi_getmaterial(s.PM);

mi_drawarc(s.PM_r + s.Seal, 0, -s.PM_r - s.Seal, 0, 180, s.max_segment);
mi_drawarc(-s.PM_r - s.Seal, 0, s.PM_r + s.Seal, 0, 180, s.max_segment);

mi_drawarc(s.shaft_r, 0, -s.shaft_r, 0, 180, s.max_segment);
mi_addarc(-s.shaft_r, 0, s.shaft_r, 0, 180, s.max_segment);

for pole_idx = 1:numel(s.pole_axes_deg)
    pole_axis_deg = s.pole_axes_deg(pole_idx) + rotor_mech_angle_deg;
    if mod(pole_idx, 2) == 1
        pole_magnetization_deg = mod(pole_axis_deg, 360);
    else
        pole_magnetization_deg = mod(pole_axis_deg + 180, 360);
    end

    rect_pos = compute_axis_parallel_shortedge_polygon( ...
        pole_axis_deg + s.magnet_center_offset_deg, s.magnet_center_r, ...
        pole_axis_deg + s.v_angle_deg, pole_axis_deg, ...
        s.magnet_length, s.magnet_thickness);
    rect_neg = compute_axis_parallel_shortedge_polygon( ...
        pole_axis_deg - s.magnet_center_offset_deg, s.magnet_center_r, ...
        pole_axis_deg - s.v_angle_deg, pole_axis_deg, ...
        s.magnet_length, -s.magnet_thickness);

    draw_magnet_polygon(rect_pos, pole_magnetization_deg, s.PM);
    draw_magnet_polygon(rect_neg, pole_magnetization_deg, s.PM);
end

rotor_core_label_r = s.shaft_r + 1;
mi_addblocklabel(rotor_core_label_r, 0);
mi_selectlabel(rotor_core_label_r, 0);
mi_setblockprop(s.Core, 1, 0, 0, 0, 1, 0);
mi_clearselected;

mi_addblocklabel(0, 0);
mi_selectlabel(0, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
mi_clearselected;

mi_drawarc(s.Core_ro, 0, -s.Core_ro, 0, 180, s.max_segment);
mi_addarc(-s.Core_ro, 0, s.Core_ro, 0, 180, s.max_segment);

for i = 0:s.num_slots
    h = (i - 1) * 2 * pi / 180;
    j = i * 2 * pi / 180;
    k = (i + 1) * 2 * pi / 180;
    L = (i + 2) * 2 * pi / 180;
    if mod(i, 2) == 1
        mi_drawarc(s.Core_ri * cos(h * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle - s.Teeth_angle), s.Core_ri * cos(j * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle + s.Teeth_angle), s.Core_angle + s.Teeth_angle * 2, s.max_segment);
        mi_drawline(s.Core_ri * cos(h * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * cos(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(h * s.Core_angle - s.Teeth_angle));
        mi_drawline(s.Core_ri * cos(j * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * cos(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(j * s.Core_angle + s.Teeth_angle));
        mi_drawline((s.Core_ri + s.Teeth_length) * cos(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(h * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(h * s.Core_angle));
        mi_drawline((s.Core_ri + s.Teeth_length) * cos(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle));
        mi_drawline((s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(j * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(j * s.Core_angle - s.Arc_offset));
    else
        mi_drawarc((s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(k * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(k * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(L * s.Core_angle + s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(L * s.Core_angle + s.Arc_offset), 180, s.max_segment);
        mi_drawarc(s.Core_ri * cos(h * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle + s.Teeth_angle), s.Core_ri * cos(j * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle - s.Teeth_angle), s.Core_angle - s.Teeth_angle * 2, s.max_segment);
        mi_drawline((s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(j * s.Core_angle + s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(j * s.Core_angle + s.Arc_offset));
    end
end

stator_backiron_r = (s.Core_ro + (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l)) / 2;
mi_addblocklabel(stator_backiron_r, 0);
mi_selectlabel(stator_backiron_r, 0);
mi_setblockprop(s.Core, 1, 0, 0, 0, 2, 0);
mi_clearselected;

airgap_label_r = (s.PM_r + s.Seal + s.Core_ri) / 2;
mi_addblocklabel(airgap_label_r, 0);
mi_selectlabel(airgap_label_r, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
mi_clearselected;

mi_addblocklabel(s.PM_r * 5, 0);
mi_selectlabel(s.PM_r * 5, 0);
mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
mi_clearselected;

slot_center_deg = 15:20:355;
slot_label_radius = (s.Core_ri + s.Teeth_length2 + s.Slot_l) * cosd(5);
slot_circuit_names = { ...
    s.Coilname{1}, s.Coilname{1}, s.Coilname{3}, ...
    s.Coilname{1}, s.Coilname{2}, s.Coilname{1}, ...
    s.Coilname{3}, s.Coilname{3}, s.Coilname{2}, ...
    s.Coilname{3}, s.Coilname{1}, s.Coilname{3}, ...
    s.Coilname{2}, s.Coilname{2}, s.Coilname{1}, ...
    s.Coilname{2}, s.Coilname{3}, s.Coilname{2}};
slot_turn_signs = [ ...
     s.turns,  s.turns, -s.turns, ...
    -s.turns,  s.turns, -s.turns, ...
     s.turns,  s.turns, -s.turns, ...
    -s.turns,  s.turns, -s.turns, ...
     s.turns,  s.turns, -s.turns, ...
    -s.turns,  s.turns, -s.turns];

for i = 1:numel(s.Coilname)
    mi_addcircprop(s.Coilname{i}, 0, 1);
end

for slot_idx = 1:numel(slot_center_deg)
    angle_deg = slot_center_deg(slot_idx);
    x = slot_label_radius * cosd(angle_deg);
    y = slot_label_radius * sind(angle_deg);
    mi_addblocklabel(x, y);
    mi_selectlabel(x, y);
    mi_setblockprop(s.Coil, 1, 0, slot_circuit_names{slot_idx}, 0, 2, slot_turn_signs(slot_idx));
    mi_clearselected;
end

mi_makeABC(7, s.Core_ro * 2, 0, 0, 0);
end

function poly = compute_axis_parallel_shortedge_polygon(center_angle_deg, center_r, body_angle_deg, pole_axis_deg, magnet_length, signed_thickness)
center_rad = deg2rad(center_angle_deg);
body_rad = deg2rad(body_angle_deg);
axis_rad = deg2rad(pole_axis_deg);

center_xy = center_r * [cos(center_rad), sin(center_rad)];
long_vec = magnet_length * [cos(body_rad), sin(body_rad)];
short_vec = signed_thickness * [cos(axis_rad), sin(axis_rad)];

poly = [ ...
    center_xy - 0.5 * long_vec - 0.5 * short_vec; ...
    center_xy + 0.5 * long_vec - 0.5 * short_vec; ...
    center_xy + 0.5 * long_vec + 0.5 * short_vec; ...
    center_xy - 0.5 * long_vec + 0.5 * short_vec];
end

function draw_magnet_polygon(poly, magnetization_deg, material_name)
for idx = 1:4
    p0 = poly(idx, :);
    p1 = poly(mod(idx, 4) + 1, :);
    mi_drawline(p0(1), p0(2), p1(1), p1(2));
end

label_xy = mean(poly, 1);
mi_addblocklabel(label_xy(1), label_xy(2));
mi_selectlabel(label_xy(1), label_xy(2));
mi_setblockprop(material_name, 1, 0, 0, magnetization_deg, 1, 0);
mi_clearselected;
end

function ensure_femm_path_local()
femm_mfiles = 'C:\femm42\mfiles';
if exist('openfemm', 'file') ~= 2
    addpath(femm_mfiles);
end
end

function safe_close_femm_local()
try
    mo_close;
catch
end
try
    mi_close;
catch
end
try
    closefemm;
catch
end
end
