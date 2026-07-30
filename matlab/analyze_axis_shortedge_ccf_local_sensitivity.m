%% analyze_axis_shortedge_ccf_local_sensitivity.m
% Local one-factor sensitivity study around prior strong candidates run 8 and run 121.

study_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_axis_shortedge_ccf_local_sensitivity');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_local_sensitivity.csv');
run(fullfile(pwd, 'analyze_axis_shortedge_ccf.m'));
