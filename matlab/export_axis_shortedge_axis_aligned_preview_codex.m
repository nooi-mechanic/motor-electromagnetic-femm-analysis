%% export_axis_shortedge_axis_aligned_preview_codex.m
% Export a single FEM preview with rotor pole axes aligned to
% 0/90/180/270 deg for visual inspection.

ensure_femm_path_local();

settings = default_v_ipm_m19_settings_codex();
settings.rotor_mech_angle_deg = 0;
settings.magnet_length = 15.0;
settings.magnet_thickness = 4.0;
settings.v_angle_deg = 52.5; % included V angle = 105 deg

tip_gap_mm = 1.0;
center_chord_mm = tip_gap_mm + settings.magnet_length * sind(settings.v_angle_deg);
settings.magnet_center_offset_deg = asind(center_chord_mm / (2 * settings.magnet_center_r));

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_axis_aligned_preview_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

fem_filename = fullfile(output_dir, sprintf( ...
    'single_axis_parallel_shortedge_axis_aligned_tipgap_%0.1fmm.fem', tip_gap_mm));

openfemm(1);
cleanup_femm = onCleanup(@() safe_close_femm_local()); %#ok<NASGU>

newdocument(0);
mi_probdef(0, 'millimeters', 'planar', 1E-8, settings.depth, 30, 0);
build_motor_model_axis_parallel_shortedge(0, settings);
mi_saveas(fem_filename);

fprintf('Saved axis-aligned FEM preview to %s\n', fem_filename);
fprintf('tip_gap_mm=%.3f, center_chord_mm=%.3f, magnet_center_offset_deg=%.6f\n', ...
    tip_gap_mm, center_chord_mm, settings.magnet_center_offset_deg);

clear cleanup_femm;
safe_close_femm_local();

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

function draw_magnet_polygon(poly, magdir_deg, material_name)
for idx = 1:4
    p0 = poly(idx, :);
    p1 = poly(mod(idx, 4) + 1, :);
    mi_drawline(p0(1), p0(2), p1(1), p1(2));
end

label_pt = mean(poly, 1);
mi_addblocklabel(label_pt(1), label_pt(2));
mi_selectlabel(label_pt(1), label_pt(2));
mi_setblockprop(material_name, 1, 0, 0, magdir_deg, 1, 0);
mi_clearselected;
end

function ensure_femm_path_local()
if exist('openfemm', 'file')
    return;
end

candidate_roots = {
    'C:\femm42\mfiles'
    'C:\Program Files\femm42\mfiles'
    'C:\Program Files (x86)\femm42\mfiles'
};

for idx = 1:numel(candidate_roots)
    if exist(candidate_roots{idx}, 'dir')
        addpath(candidate_roots{idx});
        return;
    end
end

error('Could not locate FEMM mfiles path.');
end

function safe_close_femm_local()
try
    mi_close();
catch
end
try
    closefemm();
catch
end
end
