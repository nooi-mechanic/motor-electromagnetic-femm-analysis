%% analyze_v_ipm_m19_magnet_ccf_3factor_codex.m
% Three-factor CCF study for magnet thickness, magnet length, and V-angle.
% The DOE table is fixed up front and each design is geometry-validated
% before any FEMM run starts, so invalid points never reach MATLAB/FEMM.

base = default_v_ipm_m19_settings_codex();
study_dir = fullfile(pwd, 'femm_output_v_ipm_m19_magnet_ccf_3factor_codex');
if ~exist(study_dir, 'dir')
    mkdir(study_dir);
end

design_csv_path = fullfile(pwd, 'v_ipm_m19_ccf_magnet_design_points.csv');
design_table = readtable(design_csv_path);
design_table = validate_design_table(base, design_table);
writetable(design_table, fullfile(study_dir, 'design_table_validated.csv'));

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

partial_path = fullfile(study_dir, 'magnet_ccf_partial.mat');
final_path = fullfile(study_dir, 'magnet_ccf_result.mat');
summary_csv_path = fullfile(study_dir, 'magnet_ccf_summary.csv');

fprintf('MAGNET CCF STUDY START: %d designs\n', n_design);

for design_idx = 1:n_design
    row = design_table(design_idx, :);
    case_tag = sprintf('run_%02d', row.run);
    fprintf(['MAGNET CCF CASE %d/%d: t=%.3f mm, L=%.3f mm, v_half=%.3f deg ' ...
        '(included %.3f deg)\n'], ...
        design_idx, n_design, row.magnet_thickness_mm, row.magnet_length_mm, ...
        row.v_angle_deg, row.v_included_angle_deg);

    loaded = configure_loaded_case(base, row, study_dir, case_tag);
    loaded_results{design_idx} = run_v_ipm_m19_torque_sweep_codex(loaded);
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
        abs(loaded_torque_mean(design_idx));
    loaded_force_max(design_idx) = max(loaded_results{design_idx}.Fmag(loaded_valid));
    loaded_force_mean(design_idx) = mean(loaded_results{design_idx}.Fmag(loaded_valid), 'omitnan');

    cogging = configure_cogging_case(base, row, study_dir, case_tag);
    cogging_results{design_idx} = run_v_ipm_m19_torque_sweep_codex(cogging);
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

    fprintf(['MAGNET CCF DONE %s: Tmean=%.6g N.m, ripple=%.3f%%, ' ...
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

fprintf('MAGNET CCF STUDY COMPLETE: %d/%d designs, cancelled=%d\n', ...
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
loaded.Imax = 10;
loaded.use_magnets = true;
loaded.current_mode = 'default';
loaded.commutation_offset_deg = 30;
loaded.theta_deg_vals = 0:2:28;
loaded.keep_femm_files = false;
loaded.run_label = sprintf(['magnet CCF loaded run %d ' ...
    '(t=%.3f, L=%.3f, v=%.3f)'], ...
    row.run, row.magnet_thickness_mm, row.magnet_length_mm, row.v_angle_deg);
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
cogging.Imax = 0;
cogging.use_magnets = true;
cogging.current_mode = 'default';
cogging.commutation_offset_deg = 0;
cogging.theta_deg_vals = 0:1:9;
cogging.keep_femm_files = false;
cogging.run_label = sprintf(['magnet CCF cogging run %d ' ...
    '(t=%.3f, L=%.3f, v=%.3f)'], ...
    row.run, row.magnet_thickness_mm, row.magnet_length_mm, row.v_angle_deg);
cogging.file_prefix = ['cogging_' case_tag];
cogging.partial_mat_name = ['cogging_' case_tag '_partial.mat'];
cogging.final_mat_name = ['cogging_' case_tag '_result.mat'];
cogging.output_dir = fullfile(root_dir, [case_tag '_cogging']);
end

function design_table = validate_design_table(base_settings, design_table)
min_outer_bridge_mm = 2.0;
min_inner_bridge_mm = 1.5;

n_design = height(design_table);
outer_bridge_mm = nan(n_design, 1);
inner_bridge_mm = nan(n_design, 1);
geometry_safe = false(n_design, 1);

for idx = 1:n_design
    sample_settings = base_settings;
    sample_settings.magnet_thickness = design_table.magnet_thickness_mm(idx);
    sample_settings.magnet_length = design_table.magnet_length_mm(idx);
    sample_settings.v_angle_deg = design_table.v_angle_deg(idx);

    [outer_bridge_mm(idx), inner_bridge_mm(idx)] = compute_bridge_thickness(sample_settings);
    geometry_safe(idx) = outer_bridge_mm(idx) >= min_outer_bridge_mm && ...
        inner_bridge_mm(idx) >= min_inner_bridge_mm;
end

design_table.outer_bridge_mm = outer_bridge_mm;
design_table.inner_bridge_mm = inner_bridge_mm;
design_table.geometry_safe = geometry_safe;

if ~all(geometry_safe)
    invalid_rows = design_table(~geometry_safe, :);
    disp(invalid_rows);
    error('DOE contains geometry-unsafe points; refusing to start FEMM study.');
end
end

function [outer_bridge_mm, inner_bridge_mm] = compute_bridge_thickness(s)
rotor_outer_radius = s.PM_r + s.Seal;
sample_count = 240;
max_radius = -inf;
min_radius = inf;

for pole_axis_deg = s.pole_axes_deg
    for sign = [-1, 1]
        center_angle_deg = pole_axis_deg + sign * s.magnet_center_offset_deg;
        body_angle_deg = pole_axis_deg + sign * s.v_angle_deg;
        rect = compute_rectangle_geometry(center_angle_deg, s.magnet_center_r, ...
            body_angle_deg, s.magnet_length, s.magnet_thickness);

        for edge_idx = 1:4
            p0 = rect(edge_idx, :);
            p1 = rect(mod(edge_idx, 4) + 1, :);
            for sample_idx = 0:(sample_count - 1)
                alpha = sample_idx / (sample_count - 1);
                p = (1 - alpha) * p0 + alpha * p1;
                radius = hypot(p(1), p(2));
                max_radius = max(max_radius, radius);
                min_radius = min(min_radius, radius);
            end
        end
    end
end

outer_bridge_mm = rotor_outer_radius - max_radius;
inner_bridge_mm = min_radius - s.shaft_r;
end

function rect = compute_rectangle_geometry(center_angle_deg, center_r, body_angle_deg, magnet_length, magnet_thickness)
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

rect = [ ...
    cx + along_x * half_length + normal_x * half_thickness, cy + along_y * half_length + normal_y * half_thickness; ...
    cx + along_x * half_length - normal_x * half_thickness, cy + along_y * half_length - normal_y * half_thickness; ...
    cx - along_x * half_length - normal_x * half_thickness, cy - along_y * half_length - normal_y * half_thickness; ...
    cx - along_x * half_length + normal_x * half_thickness, cy - along_y * half_length + normal_y * half_thickness];
end
