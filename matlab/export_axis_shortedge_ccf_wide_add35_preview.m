%% export_axis_shortedge_ccf_wide_add35_preview.m
% Export unsolved FEM previews for the wide-range 35-point axis-parallel-short-edge study.
% This is for visual geometry inspection before running the full FEMM sweep.

ensure_femm_path_local();

base = default_v_ipm_m19_settings_codex();
preview_dir = fullfile(pwd, 'femm_output_v_ipm_m19_magnet_ccf_preview_axis_parallel_shortedge_wide_add35');
if ~exist(preview_dir, 'dir')
    mkdir(preview_dir);
end

design_csv_path = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_wide_add35.csv');
design_table = readtable(design_csv_path);
design_table = annotate_axis_shortedge_design_table_codex(base, design_table);
writetable(design_table, fullfile(preview_dir, 'design_table_preview.csv'));

fprintf('AXIS-PARALLEL SHORT-EDGE WIDE-ADD35 FEM PREVIEW START: %d designs\n', height(design_table));

for design_idx = 1:height(design_table)
    row = design_table(design_idx, :);
    case_tag = sprintf('preview_%03d', row.run);
    fprintf(['PREVIEW %d/%d: run=%d, t=%.3f mm, L=%.3f mm, v_half=%.3f deg ' ...
        '(included %.3f deg), tip_gap=%.3f mm, offset=%.3f deg\n'], ...
        design_idx, height(design_table), row.run, row.magnet_thickness_mm, ...
        row.magnet_length_mm, row.v_angle_deg, row.v_included_angle_deg, ...
        row.tip_gap_mm, row.magnet_center_offset_deg);

    settings = base;
    settings.magnet_thickness = row.magnet_thickness_mm;
    settings.magnet_length = row.magnet_length_mm;
    settings.v_angle_deg = row.v_angle_deg;
    settings.magnet_center_offset_deg = row.magnet_center_offset_deg;
    settings.output_dir = fullfile(preview_dir, case_tag);

    if ~exist(settings.output_dir, 'dir')
        mkdir(settings.output_dir);
    end

    fem_filename = fullfile(settings.output_dir, sprintf('%s.fem', case_tag));
    export_single_preview_fem(fem_filename, settings);
end

fprintf('AXIS-PARALLEL SHORT-EDGE WIDE-ADD35 FEM PREVIEW COMPLETE: %d designs\n', height(design_table));

function export_single_preview_fem(fem_filename, s)
openfemm(1);
cleanup_femm = onCleanup(@() safe_close_femm_local()); %#ok<NASGU>
newdocument(0);
mi_probdef(0, 'millimeters', 'planar', 1E-8, s.depth, 30, 0);
build_motor_model_axis_parallel_shortedge(0, s);
mi_saveas(fem_filename);
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
