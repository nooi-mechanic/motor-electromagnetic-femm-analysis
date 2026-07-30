%% analyze_v_ipm_m19_loaded_average_torque_comm23_10A_codex.m
% 10 A loaded torque sweep using the 23 degree commutation offset.

settings = default_v_ipm_m19_settings_codex();
settings.Imax = 10;
settings.commutation_offset_deg = 23;
settings.theta_deg_vals = 0:1:359;
settings.run_label = 'loaded torque sweep';
settings.file_prefix = 'v_ipm_loaded_comm23_10A';
settings.partial_mat_name = 'v_ipm_m19_loaded_average_torque_comm23_10A_partial.mat';
settings.final_mat_name = 'v_ipm_m19_loaded_average_torque_comm23_10A.mat';
settings.output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_loaded_average_torque_comm23_10A');

results = run_v_ipm_m19_torque_sweep_codex(settings);

disp('Loaded torque sweep complete.');
fprintf('Mean torque = %.6g\n', results.torque_mean);
fprintf('Torque min = %.6g\n', results.torque_min);
fprintf('Torque max = %.6g\n', results.torque_max);
fprintf('Peak-to-peak torque ripple = %.6g\n', results.torque_pkpk);
fprintf('Torque ripple percent = %.6g\n', results.torque_ripple_pct);
