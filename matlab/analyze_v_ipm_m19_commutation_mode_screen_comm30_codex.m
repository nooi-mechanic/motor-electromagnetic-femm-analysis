%% analyze_v_ipm_m19_commutation_mode_screen_comm30_codex.m
% Compare phase order / sign conventions at the same commutation offset.

mode_names = {'default', 'swap_bc', 'invert_all', 'swap_bc_invert_all'};
theta_deg_vals = 0:5:60;
commutation_offset_deg = 30;
Imax = 10;

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_commutation_mode_screen_comm30_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

summary_mat_path = fullfile(output_dir, 'v_ipm_m19_commutation_mode_screen_comm30_codex.mat');
progress_log_path = fullfile(output_dir, 'progress_log.txt');

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid));

n_modes = numel(mode_names);
mean_torque = nan(1, n_modes);
torque_min = nan(1, n_modes);
torque_max = nan(1, n_modes);
torque_pkpk = nan(1, n_modes);
best_theta_deg = nan(1, n_modes);
best_torque = nan(1, n_modes);
completed = false(1, n_modes);
error_flag = false(1, n_modes);
error_message = strings(1, n_modes);

log_line(log_fid, 'START commutation mode screen offset=%.1f theta=%s Imax=%.3f', ...
    commutation_offset_deg, mat2str(theta_deg_vals), Imax);

for mode_idx = 1:n_modes
    current_mode = mode_names{mode_idx};
    log_line(log_fid, 'RUN mode=%s (%d/%d)', current_mode, mode_idx, n_modes);

    try
        settings = default_v_ipm_m19_settings_codex();
        settings.Imax = Imax;
        settings.commutation_offset_deg = commutation_offset_deg;
        settings.theta_deg_vals = theta_deg_vals;
        settings.current_mode = current_mode;
        settings.run_label = sprintf('mode screen %s', current_mode);
        settings.file_prefix = sprintf('v_ipm_%s', current_mode);
        settings.partial_mat_name = sprintf('%s_partial.mat', current_mode);
        settings.final_mat_name = sprintf('%s_result.mat', current_mode);
        settings.output_dir = fullfile(output_dir, current_mode);

        results = run_v_ipm_m19_torque_sweep_codex(settings);

        mean_torque(mode_idx) = results.torque_mean;
        torque_min(mode_idx) = results.torque_min;
        torque_max(mode_idx) = results.torque_max;
        torque_pkpk(mode_idx) = results.torque_pkpk;
        best_torque(mode_idx) = max(results.torque);
        best_theta_deg(mode_idx) = results.theta_deg_vals(find(results.torque == best_torque(mode_idx), 1));
        completed(mode_idx) = true;

        log_line(log_fid, 'DONE mode=%s mean=%.6g max=%.6g@%.1f min=%.6g pkpk=%.6g', ...
            current_mode, mean_torque(mode_idx), best_torque(mode_idx), ...
            best_theta_deg(mode_idx), torque_min(mode_idx), torque_pkpk(mode_idx));
    catch ME
        error_flag(mode_idx) = true;
        error_message(mode_idx) = string(ME.message);
        log_line(log_fid, 'FAIL mode=%s msg=%s', current_mode, ME.message);
    end

    save(summary_mat_path, ...
        'mode_names', 'theta_deg_vals', 'commutation_offset_deg', ...
        'mean_torque', 'torque_min', 'torque_max', 'torque_pkpk', ...
        'best_theta_deg', 'best_torque', ...
        'completed', 'error_flag', 'error_message');
end

[~, best_idx] = max(mean_torque);
if ~isempty(best_idx) && isfinite(mean_torque(best_idx))
    log_line(log_fid, 'COMPLETE best_mode=%s mean=%.6g max=%.6g@%.1f pkpk=%.6g', ...
        mode_names{best_idx}, mean_torque(best_idx), best_torque(best_idx), ...
        best_theta_deg(best_idx), torque_pkpk(best_idx));
end

disp('Commutation mode screen complete.');
disp(table(mode_names(:), mean_torque(:), torque_min(:), torque_max(:), torque_pkpk(:), best_theta_deg(:), ...
    'VariableNames', {'mode','mean_torque','torque_min','torque_max','torque_pkpk','best_theta_deg'}));

function log_line(log_fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
stamp = datestr(now, 31);
fprintf('[%s] %s\n', stamp, msg);
fprintf(log_fid, '[%s] %s\n', stamp, msg);
drawnow('limitrate');
end
