%% analyze_axis_shortedge_ccf.m
% Loaded/cogging CCF analysis for the axis-parallel-short-edge magnet shape.

ensure_femm_path_local();

base = default_v_ipm_m19_settings_codex();
if exist('study_dir_override', 'var') && ~isempty(study_dir_override)
    study_dir = study_dir_override;
else
    study_dir = fullfile(pwd, 'femm_output_v_ipm_m19_axis_shortedge_ccf');
end
if ~exist(study_dir, 'dir')
    mkdir(study_dir);
end

if exist('design_csv_path_override', 'var') && ~isempty(design_csv_path_override)
    design_csv_path = design_csv_path_override;
else
design_csv_path = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points.csv');
end
design_table = readtable(design_csv_path);
design_table = annotate_axis_shortedge_design_table_codex(base, design_table);
writetable(design_table, fullfile(study_dir, 'design_table_used.csv'));

n_design = height(design_table);
loaded_torque_mean = nan(n_design, 1);
loaded_torque_min = nan(n_design, 1);
loaded_torque_max = nan(n_design, 1);
loaded_torque_pkpk = nan(n_design, 1);
loaded_torque_ripple_pct = nan(n_design, 1);
loaded_force_max = nan(n_design, 1);
loaded_force_mean = nan(n_design, 1);
cogging_torque_pkpk = nan(n_design, 1);
completed_design = false(n_design, 1);
cancelled = false;
loaded_results = cell(n_design, 1);
cogging_results = cell(n_design, 1);

partial_path = fullfile(study_dir, 'axis_shortedge_ccf_partial.mat');
final_path = fullfile(study_dir, 'axis_shortedge_ccf_result.mat');
summary_csv_path = fullfile(study_dir, 'axis_shortedge_ccf_summary.csv');

fprintf('AXIS SHORTEDGE CCF STUDY START: %d designs\n', n_design);

for design_idx = 1:n_design
    row = design_table(design_idx, :);
    case_tag = sprintf('run_%02d', row.run);
    fprintf(['AXIS SHORTEDGE CCF CASE %d/%d: t=%.3f mm, L=%.3f mm, v_half=%.3f deg ' ...
        '(included %.3f deg), tip_gap=%.3f mm, offset=%.3f deg\n'], ...
        design_idx, n_design, row.magnet_thickness_mm, row.magnet_length_mm, ...
        row.v_angle_deg, row.v_included_angle_deg, row.tip_gap_mm, row.magnet_center_offset_deg);

    loaded = configure_loaded_case(base, row, study_dir, case_tag);
    loaded_results{design_idx} = run_axis_shortedge_torque_sweep(loaded);
    if loaded_results{design_idx}.cancelled
        cancelled = true;
        save_partial_results(partial_path, design_table, completed_design, ...
            loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
            loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
            loaded_force_max, loaded_force_mean, cancelled, ...
            loaded_results, cogging_results);
        break;
    end

    loaded_valid = loaded_results{design_idx}.completed & ~loaded_results{design_idx}.error_flag;
    if ~any(loaded_valid)
        warning('No valid loaded cases for %s; skipping design.', case_tag);
        save_partial_results(partial_path, design_table, completed_design, ...
            loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
            loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
            loaded_force_max, loaded_force_mean, cancelled, ...
            loaded_results, cogging_results);
        continue;
    end

    loaded_torque_mean(design_idx) = mean(loaded_results{design_idx}.torque(loaded_valid), 'omitnan');
    loaded_torque_min(design_idx) = min(loaded_results{design_idx}.torque(loaded_valid));
    loaded_torque_max(design_idx) = max(loaded_results{design_idx}.torque(loaded_valid));
    loaded_torque_pkpk(design_idx) = loaded_torque_max(design_idx) - loaded_torque_min(design_idx);
    loaded_torque_ripple_pct(design_idx) = 100 * loaded_torque_pkpk(design_idx) / ...
        max(abs(loaded_torque_mean(design_idx)), eps);
    loaded_force_max(design_idx) = max(loaded_results{design_idx}.Fmag(loaded_valid));
    loaded_force_mean(design_idx) = mean(loaded_results{design_idx}.Fmag(loaded_valid), 'omitnan');

    cogging = configure_cogging_case(base, row, study_dir, case_tag);
    cogging_results{design_idx} = run_axis_shortedge_torque_sweep(cogging);
    if cogging_results{design_idx}.cancelled
        cancelled = true;
        save_partial_results(partial_path, design_table, completed_design, ...
            loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
            loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
            loaded_force_max, loaded_force_mean, cancelled, ...
            loaded_results, cogging_results);
        break;
    end

    cogging_valid = cogging_results{design_idx}.completed & ~cogging_results{design_idx}.error_flag;
    if ~any(cogging_valid)
        warning('No valid cogging cases for %s; skipping design.', case_tag);
        save_partial_results(partial_path, design_table, completed_design, ...
            loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
            loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
            loaded_force_max, loaded_force_mean, cancelled, ...
            loaded_results, cogging_results);
        continue;
    end

    cogging_torque = cogging_results{design_idx}.torque(cogging_valid);
    cogging_torque_pkpk(design_idx) = max(cogging_torque) - min(cogging_torque);
    completed_design(design_idx) = true;
    save_partial_results(partial_path, design_table, completed_design, ...
        loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
        loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
        loaded_force_max, loaded_force_mean, cancelled, ...
        loaded_results, cogging_results);

    fprintf(['AXIS SHORTEDGE DONE %s: Tmean=%.6g N.m, ripple=%.3f%%, ' ...
        'cogging_pp=%.6g N.m, Fmax=%.6g N\n'], case_tag, ...
        loaded_torque_mean(design_idx), loaded_torque_ripple_pct(design_idx), ...
        cogging_torque_pkpk(design_idx), loaded_force_max(design_idx));
end

summary_table = [design_table, table(completed_design, loaded_torque_mean, loaded_torque_min, ...
    loaded_torque_max, loaded_torque_pkpk, loaded_torque_ripple_pct, ...
    cogging_torque_pkpk, loaded_force_max, loaded_force_mean)];
writetable(summary_table, summary_csv_path);

save(final_path, '-v7', 'design_table', 'summary_table', 'completed_design', ...
    'loaded_torque_mean', 'loaded_torque_min', 'loaded_torque_max', ...
    'loaded_torque_pkpk', 'loaded_torque_ripple_pct', 'cogging_torque_pkpk', ...
    'loaded_force_max', 'loaded_force_mean', 'cancelled', ...
    'loaded_results', 'cogging_results');

fprintf('AXIS SHORTEDGE CCF STUDY COMPLETE: %d/%d designs, cancelled=%d\n', ...
    nnz(completed_design), n_design, cancelled);

function save_partial_results(partial_path, design_table, completed_design, ...
    loaded_torque_mean, loaded_torque_min, loaded_torque_max, ...
    loaded_torque_pkpk, loaded_torque_ripple_pct, cogging_torque_pkpk, ...
    loaded_force_max, loaded_force_mean, cancelled, ...
    loaded_results, cogging_results)
save(partial_path, '-v7', 'design_table', 'completed_design', ...
    'loaded_torque_mean', 'loaded_torque_min', 'loaded_torque_max', ...
    'loaded_torque_pkpk', 'loaded_torque_ripple_pct', 'cogging_torque_pkpk', ...
    'loaded_force_max', 'loaded_force_mean', 'cancelled', ...
    'loaded_results', 'cogging_results');
end

function loaded = configure_loaded_case(base_settings, row, root_dir, case_tag)
loaded = base_settings;
loaded.magnet_thickness = row.magnet_thickness_mm;
loaded.magnet_length = row.magnet_length_mm;
loaded.v_angle_deg = row.v_angle_deg;
loaded.magnet_center_offset_deg = row.magnet_center_offset_deg;
loaded.Imax = 10;
loaded.use_magnets = true;
loaded.current_mode = 'default';
loaded.commutation_offset_deg = 30;
loaded.theta_deg_vals = 0:2:28;
loaded.keep_femm_files = false;
loaded.solve_model = true;
loaded.run_label = sprintf(['axis shortedge loaded run %d ' ...
    '(t=%.3f, L=%.3f, v=%.3f, gap=%.3f)'], ...
    row.run, row.magnet_thickness_mm, row.magnet_length_mm, row.v_angle_deg, row.tip_gap_mm);
loaded.file_prefix = ['loaded_' case_tag];
loaded.partial_mat_name = ['loaded_' case_tag '_partial.mat'];
loaded.final_mat_name = ['loaded_' case_tag '_result.mat'];
loaded.output_dir = fullfile(root_dir, [case_tag '_loaded']);
end

function cogging = configure_cogging_case(base_settings, row, root_dir, case_tag)
cogging = base_settings;
cogging.magnet_thickness = row.magnet_thickness_mm;
cogging.magnet_length = row.magnet_length_mm;
cogging.v_angle_deg = row.v_angle_deg;
cogging.magnet_center_offset_deg = row.magnet_center_offset_deg;
cogging.Imax = 0;
cogging.use_magnets = true;
cogging.current_mode = 'default';
cogging.commutation_offset_deg = 0;
cogging.theta_deg_vals = 0:1:9;
cogging.keep_femm_files = false;
cogging.solve_model = true;
cogging.run_label = sprintf(['axis shortedge cogging run %d ' ...
    '(t=%.3f, L=%.3f, v=%.3f, gap=%.3f)'], ...
    row.run, row.magnet_thickness_mm, row.magnet_length_mm, row.v_angle_deg, row.tip_gap_mm);
cogging.file_prefix = ['cogging_' case_tag];
cogging.partial_mat_name = ['cogging_' case_tag '_partial.mat'];
cogging.final_mat_name = ['cogging_' case_tag '_result.mat'];
cogging.output_dir = fullfile(root_dir, [case_tag '_cogging']);
end

function results = run_axis_shortedge_torque_sweep(settings)
if ~exist(settings.output_dir, 'dir')
    mkdir(settings.output_dir);
end

progress_log_path = fullfile(settings.output_dir, 'progress_log.txt');
summary_mat_path = fullfile(settings.output_dir, settings.partial_mat_name);
cancel_path = fullfile(pwd, 'codex_job_cancel.txt');
cancelled = false;

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid)); %#ok<NASGU>

n_theta = numel(settings.theta_deg_vals);
torque = nan(1, n_theta);
F_x = nan(1, n_theta);
F_y = nan(1, n_theta);
Ia_hist = nan(1, n_theta);
Ib_hist = nan(1, n_theta);
Ic_hist = nan(1, n_theta);
completed = false(1, n_theta);
error_flag = false(1, n_theta);
elapsed_sec = nan(1, n_theta);
error_message = strings(1, n_theta);

log_line(log_fid, 'START %s with %d cases, Imax=%.3f, commutation_offset_deg=%.3f, current_mode=%s', ...
    settings.run_label, n_theta, settings.Imax, settings.commutation_offset_deg, settings.current_mode);

for theta_idx = 1:n_theta
    if exist(cancel_path, 'file')
        cancelled = true;
        delete(cancel_path);
        log_line(log_fid, 'CANCEL requested before case %d/%d; preserving partial results', theta_idx, n_theta);
        break;
    end

    theta_deg = settings.theta_deg_vals(theta_idx);
    mech_theta_deg = get_mech_theta_deg_local(settings, theta_idx, theta_deg);
    elec_theta_deg = get_elec_theta_deg_local(settings, theta_idx, theta_deg);
    fem_filename = fullfile(settings.output_dir, sprintf('%s_%03ddeg.fem', settings.file_prefix, round(theta_deg)));
    ans_filename = fullfile(settings.output_dir, sprintf('%s_%03ddeg.ans', settings.file_prefix, round(theta_deg)));
    step_tic = tic;

    log_line(log_fid, 'RUN theta=%.1f mech=%.1f elec=%.1f (%d/%d)', ...
        theta_deg, mech_theta_deg, elec_theta_deg, theta_idx, n_theta);

    try
        openfemm(1);
        newdocument(0);
        mi_probdef(0, 'millimeters', 'planar', 1E-8, settings.depth, 30, 0);

        build_motor_model_axis_parallel_shortedge(mech_theta_deg, settings);

        theta_elec_rad = deg2rad(elec_theta_deg);
        [Ia, Ib, Ic] = compute_phase_currents_local(theta_elec_rad, settings);
        Ia_hist(theta_idx) = Ia;
        Ib_hist(theta_idx) = Ib;
        Ic_hist(theta_idx) = Ic;

        mi_setcurrent(settings.Coilname{1}, Ia);
        mi_setcurrent(settings.Coilname{2}, Ib);
        mi_setcurrent(settings.Coilname{3}, Ic);

        mi_saveas(fem_filename);
        log_line(log_fid, 'ANALYZE theta=%.1f fem=%s', theta_deg, fem_filename);

        mi_analyze;
        mi_loadsolution;

        mo_groupselectblock(1);
        torque(theta_idx) = mo_blockintegral(22);
        F_x(theta_idx) = mo_blockintegral(18);
        F_y(theta_idx) = mo_blockintegral(19);
        mo_clearblock;

        completed(theta_idx) = true;
        elapsed_sec(theta_idx) = toc(step_tic);
        log_line(log_fid, 'DONE theta=%.1f elapsed=%.2f s torque=%.6g ans=%s', ...
            theta_deg, elapsed_sec(theta_idx), torque(theta_idx), ans_filename);
    catch ME
        error_flag(theta_idx) = true;
        elapsed_sec(theta_idx) = toc(step_tic);
        error_message(theta_idx) = string(ME.message);
        log_line(log_fid, 'FAIL theta=%.1f elapsed=%.2f s msg=%s', ...
            theta_deg, elapsed_sec(theta_idx), ME.message);
    end

    safe_close_femm_local();
    pause(0.2);

    if isfield(settings, 'keep_femm_files') && ~settings.keep_femm_files
        cleanup_case_files_local(fem_filename);
    end

    theta_deg_vals = settings.theta_deg_vals; %#ok<NASGU>
    save_with_retry_local(summary_mat_path, 'theta_deg_vals', 'torque', 'F_x', 'F_y', ...
        'Ia_hist', 'Ib_hist', 'Ic_hist', 'completed', 'error_flag', ...
        'elapsed_sec', 'error_message');
end

valid_idx = completed & ~error_flag;
Fmag = hypot(F_x, F_y);
if any(valid_idx)
    torque_mean = mean(torque(valid_idx), 'omitnan');
    torque_min = min(torque(valid_idx));
    torque_max = max(torque(valid_idx));
    torque_pkpk = torque_max - torque_min;
    torque_ripple_pct = 100 * torque_pkpk / max(abs(torque_mean), eps);
else
    torque_mean = nan;
    torque_min = nan;
    torque_max = nan;
    torque_pkpk = nan;
    torque_ripple_pct = nan;
end

results = struct();
results.theta_deg_vals = settings.theta_deg_vals;
results.torque = torque;
results.F_x = F_x;
results.F_y = F_y;
results.Fmag = Fmag;
results.Ia_hist = Ia_hist;
results.Ib_hist = Ib_hist;
results.Ic_hist = Ic_hist;
results.completed = completed;
results.error_flag = error_flag;
results.elapsed_sec = elapsed_sec;
results.error_message = error_message;
results.cancelled = cancelled;
results.torque_mean = torque_mean;
results.torque_min = torque_min;
results.torque_max = torque_max;
results.torque_pkpk = torque_pkpk;
results.torque_ripple_pct = torque_ripple_pct;

save(fullfile(settings.output_dir, settings.final_mat_name), '-struct', 'results');

if cancelled
    log_line(log_fid, 'CANCELLED completed=%d failed=%d mean_torque=%.6g pkpk=%.6g ripple_pct=%.6g', ...
        nnz(completed), nnz(error_flag), torque_mean, torque_pkpk, torque_ripple_pct);
else
    log_line(log_fid, 'COMPLETE completed=%d failed=%d mean_torque=%.6g pkpk=%.6g ripple_pct=%.6g', ...
        nnz(completed), nnz(error_flag), torque_mean, torque_pkpk, torque_ripple_pct);
end
end

function build_motor_model_axis_parallel_shortedge(theta_deg, s)
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

    draw_magnet_polygon(rect_pos, pole_magnetization_deg, ternary_local(s.use_magnets, s.PM, 'Air'));
    draw_magnet_polygon(rect_neg, pole_magnetization_deg, ternary_local(s.use_magnets, s.PM, 'Air'));
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
if strcmp(material_name, 'Air')
    mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
else
    mi_setblockprop(material_name, 1, 0, 0, magnetization_deg, 1, 0);
end
mi_clearselected;
end

function [Ia, Ib, Ic] = compute_phase_currents_local(theta_elec_rad, settings)
Ia0 = -settings.Imax * sin(theta_elec_rad);
Ib0 = -settings.Imax * sin(theta_elec_rad - 2 * pi / 3);
Ic0 = -settings.Imax * sin(theta_elec_rad + 2 * pi / 3);
switch settings.current_mode
    case 'default'
        Ia = Ia0; Ib = Ib0; Ic = Ic0;
    case 'swap_bc'
        Ia = Ia0; Ib = Ic0; Ic = Ib0;
    case 'invert_all'
        Ia = -Ia0; Ib = -Ib0; Ic = -Ic0;
    case 'swap_bc_invert_all'
        Ia = -Ia0; Ib = -Ic0; Ic = -Ib0;
    otherwise
        error('Unknown current_mode: %s', settings.current_mode);
end
end

function mech_theta_deg = get_mech_theta_deg_local(settings, theta_idx, fallback_theta_deg)
if isfield(settings, 'mech_theta_deg_vals') && ~isempty(settings.mech_theta_deg_vals)
    mech_theta_deg = settings.mech_theta_deg_vals(theta_idx);
else
    mech_theta_deg = fallback_theta_deg;
end
end

function elec_theta_deg = get_elec_theta_deg_local(settings, theta_idx, fallback_theta_deg)
if isfield(settings, 'elec_theta_deg_vals') && ~isempty(settings.elec_theta_deg_vals)
    elec_theta_deg = settings.elec_theta_deg_vals(theta_idx);
else
    elec_theta_deg = settings.pole_pairs * (fallback_theta_deg + settings.commutation_offset_deg);
end
end

function value = ternary_local(cond, value_true, value_false)
if cond
    value = value_true;
else
    value = value_false;
end
end

function ensure_femm_path_local()
femm_mfiles = 'C:\femm42\mfiles';
if exist('openfemm', 'file') ~= 2
    addpath(femm_mfiles);
end
end

function cleanup_case_files_local(fem_filename)
if exist(fem_filename, 'file')
    delete_with_retry_local(fem_filename);
end
ans_filename = strrep(fem_filename, '.fem', '.ans');
if exist(ans_filename, 'file')
    delete_with_retry_local(ans_filename);
end
end

function delete_with_retry_local(file_path)
last_err = [];
for attempt = 1:5
    try
        if exist(file_path, 'file')
            delete(file_path);
        end
        return;
    catch ME
        last_err = ME;
        pause(0.2 * attempt);
    end
end
if ~isempty(last_err)
    warning('File not found or permission denied');
end
end

function save_with_retry_local(file_path, varargin)
last_err = [];
for attempt = 1:5
    try
        save_vars = struct();
        for var_idx = 1:numel(varargin)
            var_name = varargin{var_idx};
            save_vars.(var_name) = evalin('caller', var_name);
        end
        save(file_path, '-struct', 'save_vars');
        return;
    catch ME
        last_err = ME;
        pause(0.2 * attempt);
    end
end
rethrow(last_err);
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

function log_line(log_fid, fmt, varargin)
timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
fprintf(log_fid, '[%s] %s\n', timestamp, sprintf(fmt, varargin{:}));
end
