%% analyze_v_ipm_m19_cogging_torque_comm23_codex.m
% Zero-current cogging torque sweep using the current commutation study geometry.

settings = default_v_ipm_m19_settings_codex();
settings.Imax = 0;
settings.commutation_offset_deg = 23;
settings.theta_deg_vals = 0:1:359;
settings.run_label = 'cogging torque sweep';
settings.file_prefix = 'v_ipm_cogging_comm23';
settings.partial_mat_name = 'v_ipm_m19_cogging_torque_comm23_partial.mat';
settings.final_mat_name = 'v_ipm_m19_cogging_torque_comm23.mat';
settings.output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_cogging_torque_comm23');

results = run_v_ipm_m19_torque_sweep_codex(settings);

disp('Cogging torque sweep complete.');
fprintf('Mean torque = %.6g\n', results.torque_mean);
fprintf('Peak-to-peak cogging torque = %.6g\n', results.torque_pkpk);
