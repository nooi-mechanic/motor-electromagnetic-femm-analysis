%% analyze_axis_shortedge_ccf_wide_add35.m
% Wrapper for one-shot wide-range CCF exploration using 35 new FEMM points.
% Intended to be combined later with the existing 15 measured points.

study_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add35');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_wide_add35.csv');
run(fullfile(pwd, 'analyze_axis_shortedge_ccf.m'));
