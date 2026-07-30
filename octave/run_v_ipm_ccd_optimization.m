%% run_v_ipm_ccd_optimization.m
% CCD design study for V-IPM rotor variables:
% 1) v_angle_deg
% 2) magnet_center_r
% 3) magnet_center_offset_deg
%
% For each CCD point:
% - run theta sweep
% - collect torque / tangential force / airgap field summary
% - fit quadratic response surfaces
% - compute center-point sensitivities

clc;
clear;

base_params = default_v_ipm_design();

study = struct();
study.names = {'v_angle_deg', 'magnet_center_r', 'magnet_center_offset_deg'};
study.center = [base_params.v_angle_deg, base_params.magnet_center_r, base_params.magnet_center_offset_deg];
study.step = [10, 2, 4];
study.alpha = nthroot(2^numel(study.names), 4);
study.center_repeats = 3;

opts = struct();
opts.case_name = 'v_ipm_ccd';
opts.output_dir = fullfile(pwd, 'femm_output_v_ipm_ccd');
opts.theta_deg_vals = 0:1:359;
opts.Imax = 0;
opts.pole_pairs = 2;
opts.rotation_sign = 1;
opts.commutation_offset_deg = 0;
opts.sample_airgap = true;

if ~exist(opts.output_dir, 'dir')
    mkdir(opts.output_dir);
end

coded_design = build_ccd_matrix(numel(study.names), study.alpha, study.center_repeats);
actual_design = coded_to_actual(coded_design, study.center, study.step);

num_runs = size(actual_design, 1);
summary = struct();
summary.run_id = (1:num_runs).';
summary.v_angle_deg = actual_design(:, 1);
summary.magnet_center_r = actual_design(:, 2);
summary.magnet_center_offset_deg = actual_design(:, 3);
summary.mean_torque = zeros(num_runs, 1);
summary.torque_pp = zeros(num_runs, 1);
summary.mean_thrust = zeros(num_runs, 1);
summary.thrust_pp = zeros(num_runs, 1);
summary.mean_F_x = zeros(num_runs, 1);
summary.mean_F_y = zeros(num_runs, 1);
summary.objective = zeros(num_runs, 1);
summary.case_name = cell(num_runs, 1);
all_results = cell(num_runs, 1);

for run_idx = 1:num_runs
    params = base_params;
    params.v_angle_deg = actual_design(run_idx, 1);
    params.magnet_center_r = actual_design(run_idx, 2);
    params.magnet_center_offset_deg = actual_design(run_idx, 3);

    case_name = sprintf('v_ipm_ccd_%02d', run_idx);
    case_opts = opts;
    case_opts.case_name = case_name;
    case_opts.output_dir = fullfile(opts.output_dir, case_name);

    result = simulate_v_ipm_theta_sweep(params, case_opts);
    all_results{run_idx} = result;

    objective = result.metrics.mean_thrust - 0.10 * result.metrics.thrust_pp;

    summary.mean_torque(run_idx) = result.metrics.mean_torque;
    summary.torque_pp(run_idx) = result.metrics.torque_pp;
    summary.mean_thrust(run_idx) = result.metrics.mean_thrust;
    summary.thrust_pp(run_idx) = result.metrics.thrust_pp;
    summary.mean_F_x(run_idx) = result.metrics.mean_F_x;
    summary.mean_F_y(run_idx) = result.metrics.mean_F_y;
    summary.objective(run_idx) = objective;
    summary.case_name{run_idx} = case_name;
end

write_summary_csv(fullfile(opts.output_dir, 'ccd_summary.csv'), summary);

responses = {'mean_thrust', 'thrust_pp', 'mean_torque', 'torque_pp', 'objective'};
models = struct();
sensitivities = struct();

for resp_idx = 1:numel(responses)
    response_name = responses{resp_idx};
    y = summary.(response_name);
    model = fit_quadratic_ccd(coded_design, y);
    sens = center_sensitivity_from_model(model, study.step, study.names);
    models.(response_name) = model;
    sensitivities.(response_name) = sens;
end

[best_objective, best_idx] = max(summary.objective);
best_design = structfun(@(x) pick_struct_value(x, best_idx), summary, 'UniformOutput', false);

save(fullfile(opts.output_dir, 'ccd_results.mat'), ...
    'study', 'coded_design', 'actual_design', 'summary', ...
    'models', 'sensitivities', 'all_results', 'best_objective', 'best_design');

disp('Best CCD run by objective:');
disp(best_design);

function params = default_v_ipm_design()
    params = struct();
    params.depth = 150;
    params.PM = 'N35';
    params.Core = 'SiSteel';
    params.Sealing = 'Inconel 718';
    params.Coil = '18 AWG';
    params.Coilname = {'Coil_A','Coil_B','Coil_C'};

    params.PM_r = 53/2;
    params.Seal = 5;
    params.Core_ri = 64/2;
    params.Core_ro = 150/2;
    params.Slot_l = 20;
    params.turns = 200;
    params.max_segment = 10;
    params.Core_angle = 5;
    params.num_slots = 36;
    params.Teeth_angle = pi/66.95;
    params.Teeth_length = 1;
    params.Teeth_length2 = 1;
    params.Arc_offset = 0.01*pi;

    params.shaft_r = 8;
    params.magnet_length = 15;
    params.magnet_thickness = 4;
    params.v_angle_deg = 45;
    params.magnet_center_r = params.PM_r - 6;
    params.magnet_center_offset_deg = 20;
end

function coded_design = build_ccd_matrix(k, alpha, center_repeats)
    factorial = build_two_level_factorial(k);

    axial = zeros(2*k, k);
    for i = 1:k
        axial(2*i-1, i) = alpha;
        axial(2*i, i) = -alpha;
    end

    center = zeros(center_repeats, k);
    coded_design = [factorial; axial; center];
end

function actual_design = coded_to_actual(coded_design, center, step)
    actual_design = center + coded_design .* step;
end

function model = fit_quadratic_ccd(coded_design, y)
    X = build_quadratic_regression_matrix(coded_design);
    beta = X \ y;
    y_hat = X * beta;

    residual = y - y_hat;
    ss_res = sum(residual.^2);
    ss_tot = sum((y - mean(y)).^2);
    r2 = 1 - ss_res / ss_tot;

    model = struct();
    model.beta = beta;
    model.X = X;
    model.y = y;
    model.y_hat = y_hat;
    model.r2 = r2;
end

function X = build_quadratic_regression_matrix(coded_design)
    x1 = coded_design(:,1);
    x2 = coded_design(:,2);
    x3 = coded_design(:,3);
    X = [
        ones(size(x1)), ...
        x1, x2, x3, ...
        x1.^2, x2.^2, x3.^2, ...
        x1.*x2, x1.*x3, x2.*x3
    ];
end

function sens = center_sensitivity_from_model(model, step, names)
    beta = model.beta;
    % At coded center x = 0, only linear terms contribute to first derivative.
    coded_grad = beta(2:4).';
    actual_grad = coded_grad ./ step;

    sens = struct();
    sens.variable = names(:);
    sens.coded_gradient = coded_grad(:);
    sens.actual_gradient = actual_grad(:);
end

function factorial = build_two_level_factorial(k)
    num_rows = 2^k;
    factorial = zeros(num_rows, k);
    for row = 0:num_rows-1
        bits = dec2bin(row, k) - '0';
        factorial(row+1, :) = 2 * bits - 1;
    end
end

function write_summary_csv(filename, summary)
    fid = fopen(filename, 'w');
    fprintf(fid, 'run_id,v_angle_deg,magnet_center_r,magnet_center_offset_deg,mean_torque,torque_pp,mean_thrust,thrust_pp,mean_F_x,mean_F_y,objective,case_name\n');
    for idx = 1:numel(summary.run_id)
        fprintf(fid, '%d,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%.10g,%s\n', ...
            summary.run_id(idx), ...
            summary.v_angle_deg(idx), ...
            summary.magnet_center_r(idx), ...
            summary.magnet_center_offset_deg(idx), ...
            summary.mean_torque(idx), ...
            summary.torque_pp(idx), ...
            summary.mean_thrust(idx), ...
            summary.thrust_pp(idx), ...
            summary.mean_F_x(idx), ...
            summary.mean_F_y(idx), ...
            summary.objective(idx), ...
            summary.case_name{idx});
    end
    fclose(fid);
end

function value = pick_struct_value(field_value, idx)
    if iscell(field_value)
        value = field_value{idx};
    else
        value = field_value(idx,:);
    end
end
