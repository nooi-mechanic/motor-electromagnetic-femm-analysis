%% analyze_v_ipm_m19_airgap_sensitivity_5point_codex.m
% Five-point uniform-airgap sensitivity study using known periodic sectors.

base = default_v_ipm_m19_settings_codex();
airgap_mm = 0.5:0.1:0.9;
n_gap = numel(airgap_mm);
stator_inner_radius_mm = base.Core_ri;
rotor_outer_radius_mm = stator_inner_radius_mm - airgap_mm;
rotor_outer_diameter_mm = 2 * rotor_outer_radius_mm;

study_dir = fullfile(pwd, 'femm_output_v_ipm_m19_airgap_rotor_shrink_05_09_codex');
if ~exist(study_dir, 'dir')
    mkdir(study_dir);
end

loaded_torque_mean = nan(1, n_gap);
loaded_torque_min = nan(1, n_gap);
loaded_torque_max = nan(1, n_gap);
loaded_torque_pkpk = nan(1, n_gap);
loaded_torque_ripple_pct = nan(1, n_gap);
loaded_force_max = nan(1, n_gap);
loaded_force_mean = nan(1, n_gap);
cogging_torque_pkpk = nan(1, n_gap);
loaded_results = cell(1, n_gap);
cogging_results = cell(1, n_gap);
completed_gap = false(1, n_gap);
cancelled = false;

partial_path = fullfile(study_dir, 'airgap_sensitivity_partial.mat');
final_path = fullfile(study_dir, 'airgap_sensitivity_result.mat');
csv_path = fullfile(study_dir, 'airgap_sensitivity_summary.csv');

fprintf('AIRGAP STUDY START: %d gaps, loaded 0:2:28 deg, cogging 0:1:9 deg\n', n_gap);

for gap_idx = 1:n_gap
    gap = airgap_mm(gap_idx);
    case_tag = sprintf('g%03dum', round(1000 * gap));
    fprintf('AIRGAP CASE %d/%d: g=%.3f mm\n', gap_idx, n_gap, gap);

    loaded = base;
    loaded.Core_ri = stator_inner_radius_mm;
    loaded.Seal = rotor_outer_radius_mm(gap_idx) - loaded.PM_r;
    loaded.Imax = 10;
    loaded.use_magnets = true;
    loaded.current_mode = 'default';
    loaded.commutation_offset_deg = 30;
    loaded.theta_deg_vals = 0:2:28;
    loaded.keep_femm_files = false;
    loaded.run_label = sprintf('airgap %.3f mm loaded 10 A', gap);
    loaded.file_prefix = ['loaded_' case_tag];
    loaded.partial_mat_name = ['loaded_' case_tag '_partial.mat'];
    loaded.final_mat_name = ['loaded_' case_tag '_result.mat'];
    loaded.output_dir = fullfile(study_dir, [case_tag '_loaded']);

    loaded_results{gap_idx} = run_v_ipm_m19_torque_sweep_codex(loaded);
    if loaded_results{gap_idx}.cancelled
        cancelled = true;
        save(partial_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
            'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
            'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
            'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
            'cogging_torque_pkpk', 'completed_gap', 'cancelled', ...
            'loaded_results', 'cogging_results');
        break;
    end

    loaded_valid = loaded_results{gap_idx}.completed & ~loaded_results{gap_idx}.error_flag;
    if ~any(loaded_valid)
        warning('No valid loaded cases for g=%.3f mm; skipping this gap.', gap);
        save(partial_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
            'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
            'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
            'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
            'cogging_torque_pkpk', 'completed_gap', 'cancelled', ...
            'loaded_results', 'cogging_results');
        continue;
    end
    loaded_torque_mean(gap_idx) = mean(loaded_results{gap_idx}.torque(loaded_valid), 'omitnan');
    loaded_torque_min(gap_idx) = min(loaded_results{gap_idx}.torque(loaded_valid));
    loaded_torque_max(gap_idx) = max(loaded_results{gap_idx}.torque(loaded_valid));
    loaded_torque_pkpk(gap_idx) = loaded_torque_max(gap_idx) - loaded_torque_min(gap_idx);
    loaded_torque_ripple_pct(gap_idx) = 100 * loaded_torque_pkpk(gap_idx) / abs(loaded_torque_mean(gap_idx));
    loaded_force_max(gap_idx) = max(loaded_results{gap_idx}.Fmag(loaded_valid));
    loaded_force_mean(gap_idx) = mean(loaded_results{gap_idx}.Fmag(loaded_valid), 'omitnan');

    cogging = base;
    cogging.Core_ri = stator_inner_radius_mm;
    cogging.Seal = rotor_outer_radius_mm(gap_idx) - cogging.PM_r;
    cogging.Imax = 0;
    cogging.use_magnets = true;
    cogging.current_mode = 'default';
    cogging.commutation_offset_deg = 0;
    cogging.theta_deg_vals = 0:1:9;
    cogging.keep_femm_files = false;
    cogging.run_label = sprintf('airgap %.3f mm cogging', gap);
    cogging.file_prefix = ['cogging_' case_tag];
    cogging.partial_mat_name = ['cogging_' case_tag '_partial.mat'];
    cogging.final_mat_name = ['cogging_' case_tag '_result.mat'];
    cogging.output_dir = fullfile(study_dir, [case_tag '_cogging']);

    cogging_results{gap_idx} = run_v_ipm_m19_torque_sweep_codex(cogging);
    if cogging_results{gap_idx}.cancelled
        cancelled = true;
        save(partial_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
            'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
            'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
            'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
            'cogging_torque_pkpk', 'completed_gap', 'cancelled', ...
            'loaded_results', 'cogging_results');
        break;
    end

    cogging_valid = cogging_results{gap_idx}.completed & ~cogging_results{gap_idx}.error_flag;
    if ~any(cogging_valid)
        warning('No valid cogging cases for g=%.3f mm; skipping this gap.', gap);
        save(partial_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
            'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
            'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
            'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
            'cogging_torque_pkpk', 'completed_gap', 'cancelled', ...
            'loaded_results', 'cogging_results');
        continue;
    end
    cogging_torque = cogging_results{gap_idx}.torque(cogging_valid);
    cogging_torque_pkpk(gap_idx) = max(cogging_torque) - min(cogging_torque);
    completed_gap(gap_idx) = true;

    save(partial_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
        'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
        'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
        'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
        'cogging_torque_pkpk', 'completed_gap', 'cancelled', ...
        'loaded_results', 'cogging_results');

    fprintf(['AIRGAP DONE g=%.3f mm: Tmean=%.6g N.m, ripple=%.3f%%, ' ...
        'cogging_pp=%.6g N.m, Fmax=%.6g N\n'], gap, ...
        loaded_torque_mean(gap_idx), loaded_torque_ripple_pct(gap_idx), ...
        cogging_torque_pkpk(gap_idx), loaded_force_max(gap_idx));
end

summary_table = table(airgap_mm(:), rotor_outer_diameter_mm(:), completed_gap(:), loaded_torque_mean(:), ...
    loaded_torque_min(:), loaded_torque_max(:), loaded_torque_pkpk(:), ...
    loaded_torque_ripple_pct(:), cogging_torque_pkpk(:), ...
    loaded_force_max(:), loaded_force_mean(:), ...
    'VariableNames', {'airgap_mm', 'rotor_outer_diameter_mm', 'completed', 'torque_mean_Nm', ...
    'torque_min_Nm', 'torque_max_Nm', 'torque_pkpk_Nm', ...
    'torque_ripple_pct', 'cogging_pkpk_Nm', 'force_max_N', 'force_mean_N'});
writetable(summary_table, csv_path);

sensitivity = struct();
if all(completed_gap(1:2))
    dg = airgap_mm(2) - airgap_mm(1);
    g0 = airgap_mm(1);
    sensitivity.torque_mean_per_mm = (loaded_torque_mean(2) - loaded_torque_mean(1)) / dg;
    sensitivity.torque_mean_normalized = g0 / loaded_torque_mean(1) * sensitivity.torque_mean_per_mm;
    sensitivity.torque_ripple_pct_per_mm = (loaded_torque_ripple_pct(2) - loaded_torque_ripple_pct(1)) / dg;
    sensitivity.cogging_pkpk_per_mm = (cogging_torque_pkpk(2) - cogging_torque_pkpk(1)) / dg;
    sensitivity.force_max_per_mm = (loaded_force_max(2) - loaded_force_max(1)) / dg;
end

save(final_path, '-v7', 'airgap_mm', 'stator_inner_radius_mm', ...
    'rotor_outer_radius_mm', 'rotor_outer_diameter_mm', 'loaded_torque_mean', ...
    'loaded_torque_min', 'loaded_torque_max', 'loaded_torque_pkpk', ...
    'loaded_torque_ripple_pct', 'loaded_force_max', 'loaded_force_mean', ...
    'cogging_torque_pkpk', 'completed_gap', 'cancelled', 'sensitivity', ...
    'summary_table', 'loaded_results', 'cogging_results');

fprintf('AIRGAP STUDY COMPLETE: %d/%d gaps, cancelled=%d\n', ...
    nnz(completed_gap), n_gap, cancelled);
