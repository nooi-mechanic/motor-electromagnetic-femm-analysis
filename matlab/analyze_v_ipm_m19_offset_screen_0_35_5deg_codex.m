%% analyze_v_ipm_m19_offset_screen_0_35_5deg_codex.m
% Screen commutation offsets quickly before committing to a full 360 deg run.

ensure_femm_path();

offset_deg_vals = 0:5:35;
theta_deg_vals = 0:5:60;
Imax = 10;

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_offset_screen_0_35_5deg_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

summary_mat_path = fullfile(output_dir, 'v_ipm_m19_offset_screen_0_35_5deg_codex.mat');
progress_log_path = fullfile(output_dir, 'progress_log.txt');

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid));

n_offsets = numel(offset_deg_vals);
mean_torque = nan(1, n_offsets);
torque_min = nan(1, n_offsets);
torque_max = nan(1, n_offsets);
torque_pkpk = nan(1, n_offsets);
best_theta_deg = nan(1, n_offsets);
best_torque = nan(1, n_offsets);
result_mat_paths = strings(1, n_offsets);
completed = false(1, n_offsets);
error_flag = false(1, n_offsets);
error_message = strings(1, n_offsets);

log_line(log_fid, 'START offset screen offsets=%s theta=%s Imax=%.3f', ...
    mat2str(offset_deg_vals), mat2str(theta_deg_vals), Imax);

for offset_idx = 1:n_offsets
    commutation_offset_deg = offset_deg_vals(offset_idx);
    log_line(log_fid, 'RUN offset=%.1f (%d/%d)', commutation_offset_deg, offset_idx, n_offsets);

    try
        settings = default_v_ipm_m19_settings_codex();
        settings.Imax = Imax;
        settings.commutation_offset_deg = commutation_offset_deg;
        settings.theta_deg_vals = theta_deg_vals;
        settings.run_label = sprintf('offset screen sweep offset=%.1f', commutation_offset_deg);
        settings.file_prefix = sprintf('v_ipm_offset_%02d', round(commutation_offset_deg));
        settings.partial_mat_name = sprintf('offset_%02d_partial.mat', round(commutation_offset_deg));
        settings.final_mat_name = sprintf('offset_%02d_result.mat', round(commutation_offset_deg));
        settings.output_dir = fullfile(output_dir, sprintf('offset_%02d', round(commutation_offset_deg)));

        results = run_v_ipm_m19_torque_sweep_codex(settings);

        mean_torque(offset_idx) = results.torque_mean;
        torque_min(offset_idx) = results.torque_min;
        torque_max(offset_idx) = results.torque_max;
        torque_pkpk(offset_idx) = results.torque_pkpk;
        best_torque(offset_idx) = max(results.torque);
        best_theta_deg(offset_idx) = results.theta_deg_vals(find(results.torque == best_torque(offset_idx), 1));
        result_mat_paths(offset_idx) = string(fullfile(settings.output_dir, settings.final_mat_name));
        completed(offset_idx) = true;

        log_line(log_fid, 'DONE offset=%.1f mean=%.6g max=%.6g@%.1f min=%.6g pkpk=%.6g', ...
            commutation_offset_deg, mean_torque(offset_idx), best_torque(offset_idx), ...
            best_theta_deg(offset_idx), torque_min(offset_idx), torque_pkpk(offset_idx));
    catch ME
        error_flag(offset_idx) = true;
        error_message(offset_idx) = string(ME.message);
        log_line(log_fid, 'FAIL offset=%.1f msg=%s', commutation_offset_deg, ME.message);
    end

    save(summary_mat_path, ...
        'offset_deg_vals', 'theta_deg_vals', ...
        'mean_torque', 'torque_min', 'torque_max', 'torque_pkpk', ...
        'best_theta_deg', 'best_torque', 'result_mat_paths', ...
        'completed', 'error_flag', 'error_message');
end

[~, best_idx] = max(mean_torque);
if ~isempty(best_idx) && isfinite(mean_torque(best_idx))
    log_line(log_fid, 'COMPLETE best_offset=%.1f mean=%.6g max=%.6g@%.1f pkpk=%.6g', ...
        offset_deg_vals(best_idx), mean_torque(best_idx), best_torque(best_idx), ...
        best_theta_deg(best_idx), torque_pkpk(best_idx));
else
    log_line(log_fid, 'COMPLETE no valid results');
end

disp('Offset screen complete.');
disp(table(offset_deg_vals(:), mean_torque(:), torque_min(:), torque_max(:), torque_pkpk(:), best_theta_deg(:), ...
    'VariableNames', {'offset_deg','mean_torque','torque_min','torque_max','torque_pkpk','best_theta_deg'}));

function ensure_femm_path()
femm_mfiles = 'C:\femm42\mfiles';
if exist('openfemm', 'file') ~= 2
    addpath(femm_mfiles);
end
if exist('openfemm', 'file') ~= 2
    error('Could not find openfemm.m. Expected FEMM mfiles at C:\femm42\mfiles');
end
end

function log_line(log_fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
stamp = datestr(now, 31);
fprintf('[%s] %s\n', stamp, msg);
fprintf(log_fid, '[%s] %s\n', stamp, msg);
drawnow('limitrate');
end
