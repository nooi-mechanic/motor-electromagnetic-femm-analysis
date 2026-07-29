%% analyze_axis_shortedge_ccf_4factor_50point_tipgap.m
% Run the axis short-edge CCF study using the 4-factor tip-gap DOE.

study_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_axis_shortedge_ccf_4factor_50point_tipgap');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_4factor_50_tipgap.csv');
run(fullfile(pwd, 'analyze_axis_shortedge_ccf.m'));
