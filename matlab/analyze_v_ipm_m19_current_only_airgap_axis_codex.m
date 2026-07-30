%% analyze_v_ipm_m19_current_only_airgap_axis_codex.m
% Sample Br around the airgap with magnets disabled.  For a four-pole
% machine the working field is spatial harmonic order two.

ensure_femm_path();

electrical_angle_deg_vals = 0:30:330;
mechanical_angle_deg_fixed = 0;
sample_mech_deg = 0:2:358;
Imax = 10;

settings = default_v_ipm_m19_settings_codex();
settings.use_magnets = false;
settings.Imax = Imax;
settings.current_mode = 'default';

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_current_only_airgap_axis_4pole_sl_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

progress_log_path = fullfile(output_dir, 'progress_log.txt');
summary_mat_path = fullfile(output_dir, 'v_ipm_m19_current_only_airgap_axis_4pole_sl_codex.mat');

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid)); %#ok<NASGU>

sample_radius_mm = (settings.PM_r + settings.Seal + settings.Core_ri) / 2;
n_case = numel(electrical_angle_deg_vals);
n_sample = numel(sample_mech_deg);

Ia_hist = nan(1, n_case);
Ib_hist = nan(1, n_case);
Ic_hist = nan(1, n_case);
fund_axis_mech_deg = nan(1, n_case);
fund_mag = nan(1, n_case);
target_harmonic_order = settings.pole_pairs;
harmonic_orders = 1:9;
harmonic_amplitude = nan(n_case, numel(harmonic_orders));
Br_samples = nan(n_case, n_sample);
completed = false(1, n_case);
error_flag = false(1, n_case);
error_message = strings(1, n_case);

log_line(log_fid, 'START current-only airgap axis check mech_fixed=%.1f elec=%s Imax=%.3f', ...
    mechanical_angle_deg_fixed, mat2str(electrical_angle_deg_vals), Imax);

for case_idx = 1:n_case
    elec_deg = electrical_angle_deg_vals(case_idx);
    fem_filename = fullfile(output_dir, sprintf('airgap_axis_%03ddeg.fem', round(elec_deg)));

    log_line(log_fid, 'RUN elec=%.1f (%d/%d)', elec_deg, case_idx, n_case);

    try
        openfemm(1);
        newdocument(0);
        mi_probdef(0, 'millimeters', 'planar', 1E-8, settings.depth, 30, 0);

        build_motor_model(mechanical_angle_deg_fixed, settings);

        [Ia, Ib, Ic] = compute_phase_currents(deg2rad(elec_deg), settings);
        Ia_hist(case_idx) = Ia;
        Ib_hist(case_idx) = Ib;
        Ic_hist(case_idx) = Ic;

        mi_setcurrent(settings.Coilname{1}, Ia);
        mi_setcurrent(settings.Coilname{2}, Ib);
        mi_setcurrent(settings.Coilname{3}, Ic);

        mi_saveas(fem_filename);
        mi_analyze;
        mi_loadsolution;

        for sample_idx = 1:n_sample
            mech_deg = sample_mech_deg(sample_idx);
            x = sample_radius_mm * cosd(mech_deg);
            y = sample_radius_mm * sind(mech_deg);
            B = mo_getb(x, y);
            Br_samples(case_idx, sample_idx) = B(1) * cosd(mech_deg) + B(2) * sind(mech_deg);
        end

        for harmonic_idx = 1:numel(harmonic_orders)
            harmonic_order = harmonic_orders(harmonic_idx);
            phase_term = exp(-1i * harmonic_order * deg2rad(sample_mech_deg));
            coefficient = mean(Br_samples(case_idx, :) .* phase_term);
            harmonic_amplitude(case_idx, harmonic_idx) = 2 * abs(coefficient);
        end

        phase_term = exp(-1i * target_harmonic_order * deg2rad(sample_mech_deg));
        target_coefficient = mean(Br_samples(case_idx, :) .* phase_term);
        fund_axis_mech_deg(case_idx) = mod( ...
            -rad2deg(angle(target_coefficient)) / target_harmonic_order, ...
            360 / target_harmonic_order);
        fund_mag(case_idx) = 2 * abs(target_coefficient);
        completed(case_idx) = true;

        log_line(log_fid, 'DONE elec=%.1f axis_mech=%.3f fund_mag=%.6g Ia=%.6g Ib=%.6g Ic=%.6g', ...
            elec_deg, fund_axis_mech_deg(case_idx), fund_mag(case_idx), Ia, Ib, Ic);
    catch ME
        error_flag(case_idx) = true;
        error_message(case_idx) = string(ME.message);
        log_line(log_fid, 'FAIL elec=%.1f msg=%s', elec_deg, ME.message);
    end

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

    save(summary_mat_path, ...
        'electrical_angle_deg_vals', 'mechanical_angle_deg_fixed', ...
        'sample_mech_deg', 'sample_radius_mm', ...
        'Ia_hist', 'Ib_hist', 'Ic_hist', ...
        'target_harmonic_order', 'harmonic_orders', 'harmonic_amplitude', ...
        'fund_axis_mech_deg', 'fund_mag', 'Br_samples', ...
        'completed', 'error_flag', 'error_message');
end

log_line(log_fid, 'COMPLETE completed=%d failed=%d', nnz(completed), nnz(error_flag));

disp(table(electrical_angle_deg_vals(:), Ia_hist(:), Ib_hist(:), Ic_hist(:), ...
    fund_axis_mech_deg(:), fund_mag(:), ...
    'VariableNames', {'elec_deg','Ia','Ib','Ic','axis_mech_deg','fund_mag'}));

function build_motor_model(theta_deg, s)
rotor_mech_angle_deg = theta_deg + s.rotor_mech_angle_deg;

mi_getmaterial('Air');
mi_getmaterial(s.Coil);
mi_getmaterial(s.Core);
if s.use_magnets
    mi_getmaterial(s.PM);
end

mi_drawarc(s.PM_r + s.Seal, 0, -s.PM_r - s.Seal, 0, 180, s.max_segment);
mi_drawarc(-s.PM_r - s.Seal, 0, s.PM_r + s.Seal, 0, 180, s.max_segment);
mi_drawarc(s.shaft_r, 0, -s.shaft_r, 0, 180, s.max_segment);
mi_addarc(-s.shaft_r, 0, s.shaft_r, 0, 180, s.max_segment);

magnet_specs = [];
for pole_idx = 1:numel(s.pole_axes_deg)
    pole_axis_deg = s.pole_axes_deg(pole_idx) + rotor_mech_angle_deg;
    if mod(pole_idx, 2) == 1
        pole_magnetization_deg = mod(pole_axis_deg, 360);
    else
        pole_magnetization_deg = mod(pole_axis_deg + 180, 360);
    end

    magnet_specs = [
        magnet_specs;
        pole_axis_deg + s.magnet_center_offset_deg, s.magnet_center_r, pole_axis_deg + s.v_angle_deg, pole_magnetization_deg;
        pole_axis_deg - s.magnet_center_offset_deg, s.magnet_center_r, pole_axis_deg - s.v_angle_deg, pole_magnetization_deg
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

    half_length = s.magnet_length / 2;
    half_thickness = s.magnet_thickness / 2;

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
    if s.use_magnets
        mi_setblockprop(s.PM, 1, 0, 0, magnetization_deg, 1, 0);
    else
        mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
    end
    mi_clearselected;
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
% Symmetric 18-slot / 4-pole / 3-phase single-layer winding.
% Slot sequence: A A C' A' B A' C C B' C' A C' B B A' B' C B'
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

function [Ia, Ib, Ic] = compute_phase_currents(theta_elec_rad, settings)
Ia = -settings.Imax * sin(theta_elec_rad);
Ib = -settings.Imax * sin(theta_elec_rad - 2 * pi / 3);
Ic = -settings.Imax * sin(theta_elec_rad + 2 * pi / 3);
end

function ensure_femm_path()
if exist('openfemm', 'file') == 2
    return;
end

candidates = {
    getenv('FEMM_MFILES')
    'C:\femm42\mfiles'
    'C:\Program Files (x86)\femm42\mfiles'
    'C:\Program Files\femm42\mfiles'
};

for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if ~isempty(candidate) && isfolder(candidate)
        addpath(candidate);
        if exist('openfemm', 'file') == 2
            fprintf('Added FEMM path: %s\n', candidate);
            return;
        end
    end
end

error(['Could not find FEMM mfiles path. Set FEMM_MFILES or install FEMM in one of: ' ...
       'C:\femm42\mfiles, C:\Program Files (x86)\femm42\mfiles, C:\Program Files\femm42\mfiles']);
end

function log_line(log_fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
stamp = datestr(now, 31);
fprintf('[%s] %s\n', stamp, msg);
fprintf(log_fid, '[%s] %s\n', stamp, msg);
drawnow('limitrate');
end
