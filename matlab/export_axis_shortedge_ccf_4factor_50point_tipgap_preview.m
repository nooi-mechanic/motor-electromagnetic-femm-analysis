%% export_axis_shortedge_ccf_4factor_50point_tipgap_preview.m
% Export unsolved FEM previews for the 4-factor tip-gap DOE.

preview_dir_override = fullfile(pwd, 'femm_output_v_ipm_m19_magnet_ccf_preview_axis_parallel_shortedge_4factor_50point_tipgap');
design_csv_path_override = fullfile(pwd, 'v_ipm_m19_ccf_axis_parallel_shortedge_design_points_4factor_50_tipgap.csv');
preview_label_override = '4FACTOR-50POINT-TIPGAP';
run(fullfile(pwd, 'export_axis_shortedge_ccf_wide_add33_preview.m'));
