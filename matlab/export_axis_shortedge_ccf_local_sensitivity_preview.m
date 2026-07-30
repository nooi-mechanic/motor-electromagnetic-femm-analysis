%% export_axis_shortedge_ccf_local_sensitivity_preview.m
% Wrapper for local one-factor sensitivity FEM previews around run 8 and run 121.

preview_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_magnet_ccf_preview_axis_parallel_shortedge_local_sensitivity');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_local_sensitivity.csv');
preview_label_override = 'LOCAL-SENSITIVITY';
run(fullfile(pwd, 'export_axis_shortedge_ccf_wide_add33_preview.m'));
