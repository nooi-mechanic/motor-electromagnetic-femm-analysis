%% analyze_axis_shortedge_ccf_wide_add33.m
% Wrapper for wide-range CCF exploration excluding structurally invalid points 105 and 133.

study_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add33');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_wide_add33.csv');
run(fullfile(pwd, 'analyze_axis_shortedge_ccf.m'));
