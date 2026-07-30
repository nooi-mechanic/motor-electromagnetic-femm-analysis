%% analyze_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex.m
% One mechanical revolution with the validated four-pole winding.

settings = default_v_ipm_m19_settings_codex();
settings.Imax = 10;
settings.use_magnets = true;
settings.current_mode = 'default';

% The runner converts mechanical offset to electrical angle using pole_pairs.
settings.commutation_offset_deg = 30; % 60 electrical degrees for four poles
settings.theta_deg_vals = 0:1:360;

settings.run_label = '4-pole winding loaded rotation, 60 electrical degree offset, 10 A';
settings.file_prefix = 'v_ipm_4pole_loaded_elec60_10A';
settings.partial_mat_name = 'v_ipm_4pole_loaded_elec60_10A_partial.mat';
settings.final_mat_name = 'v_ipm_4pole_loaded_elec60_10A_result.mat';
settings.output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex');

results = run_v_ipm_m19_torque_sweep_codex(settings);

summary_path = fullfile(settings.output_dir, 'v_ipm_m19_4pole_loaded_rotation_elec60_10A_summary.mat');
save(summary_path, 'results', 'settings');

fprintf('ROTATION COMPLETE mean=%.9g min=%.9g max=%.9g pkpk=%.9g N.m\n', ...
    results.torque_mean, results.torque_min, results.torque_max, results.torque_pkpk);
