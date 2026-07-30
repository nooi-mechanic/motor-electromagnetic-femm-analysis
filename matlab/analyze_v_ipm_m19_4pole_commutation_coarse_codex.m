%% analyze_v_ipm_m19_4pole_commutation_coarse_codex.m
% Find the positive-torque current angle for the validated 4-pole winding.

settings = default_v_ipm_m19_settings_codex();
settings.Imax = 10;
settings.use_magnets = true;
settings.current_mode = 'default';

elec_angle_deg_vals = 0:10:350;
settings.theta_deg_vals = elec_angle_deg_vals;
settings.mech_theta_deg_vals = zeros(size(elec_angle_deg_vals));
settings.elec_theta_deg_vals = elec_angle_deg_vals;
settings.commutation_offset_deg = 0;

settings.run_label = '4-pole winding commutation coarse screen';
settings.file_prefix = 'v_ipm_4pole_comm_coarse';
settings.partial_mat_name = 'v_ipm_4pole_comm_coarse_partial.mat';
settings.final_mat_name = 'v_ipm_4pole_comm_coarse_result.mat';
settings.output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_4pole_commutation_coarse_codex');

results = run_v_ipm_m19_torque_sweep_codex(settings);

[positive_peak_torque, positive_peak_idx] = max(results.torque);
[negative_peak_torque, negative_peak_idx] = min(results.torque);
best_elec_angle_deg = elec_angle_deg_vals(positive_peak_idx);
best_commutation_offset_mech_deg = best_elec_angle_deg / settings.pole_pairs;

summary_path = fullfile(settings.output_dir, 'v_ipm_m19_4pole_commutation_coarse_summary.mat');
save(summary_path, ...
    'elec_angle_deg_vals', 'best_elec_angle_deg', ...
    'best_commutation_offset_mech_deg', ...
    'positive_peak_torque', 'positive_peak_idx', ...
    'negative_peak_torque', 'negative_peak_idx', 'results');

fprintf('BEST positive torque %.9g N.m at electrical %.1f deg, mechanical offset %.1f deg\n', ...
    positive_peak_torque, best_elec_angle_deg, best_commutation_offset_mech_deg);
fprintf('MOST NEGATIVE torque %.9g N.m at electrical %.1f deg\n', ...
    negative_peak_torque, elec_angle_deg_vals(negative_peak_idx));
