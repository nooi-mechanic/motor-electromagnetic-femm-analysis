%% analyze_v_ipm_m19_4pole_commutation_refine_codex.m
% Refine the positive-torque peak found by the coarse current-angle screen.

settings = default_v_ipm_m19_settings_codex();
settings.Imax = 10;
settings.use_magnets = true;
settings.current_mode = 'default';

elec_angle_deg_vals = 50:2:70;
settings.theta_deg_vals = elec_angle_deg_vals;
settings.mech_theta_deg_vals = zeros(size(elec_angle_deg_vals));
settings.elec_theta_deg_vals = elec_angle_deg_vals;
settings.commutation_offset_deg = 0;

settings.run_label = '4-pole winding commutation refined screen';
settings.file_prefix = 'v_ipm_4pole_comm_refine';
settings.partial_mat_name = 'v_ipm_4pole_comm_refine_partial.mat';
settings.final_mat_name = 'v_ipm_4pole_comm_refine_result.mat';
settings.output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_4pole_commutation_refine_codex');

results = run_v_ipm_m19_torque_sweep_codex(settings);

[positive_peak_torque, positive_peak_idx] = max(results.torque);
best_elec_angle_deg = elec_angle_deg_vals(positive_peak_idx);
best_commutation_offset_mech_deg = best_elec_angle_deg / settings.pole_pairs;

summary_path = fullfile(settings.output_dir, 'v_ipm_m19_4pole_commutation_refine_summary.mat');
save(summary_path, 'elec_angle_deg_vals', 'best_elec_angle_deg', ...
    'best_commutation_offset_mech_deg', 'positive_peak_torque', ...
    'positive_peak_idx', 'results');

fprintf('REFINED BEST torque %.9g N.m at electrical %.1f deg, mechanical offset %.1f deg\n', ...
    positive_peak_torque, best_elec_angle_deg, best_commutation_offset_mech_deg);
