%% analyze_v_ipm_m19_current_only_mmf_check_codex.m
% Check whether abc currents create a clean rotating stator field
% with magnets disabled and rotor mechanically fixed.

ensure_femm_path();

electrical_angle_deg_vals = 0:30:330;
mechanical_angle_deg_fixed = 0;
Imax = 10;

output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_current_only_mmf_check_codex');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

summary_mat_path = fullfile(output_dir, 'v_ipm_m19_current_only_mmf_check_codex.mat');
progress_log_path = fullfile(output_dir, 'progress_log.txt');

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid));

settings = default_v_ipm_m19_settings_codex();
settings.use_magnets = false;
settings.Imax = Imax;
settings.current_mode = 'default';
settings.theta_deg_vals = electrical_angle_deg_vals;
settings.mech_theta_deg_vals = mechanical_angle_deg_fixed * ones(size(electrical_angle_deg_vals));
settings.elec_theta_deg_vals = electrical_angle_deg_vals;
settings.run_label = 'current only mmf check';
settings.file_prefix = 'v_ipm_current_only';
settings.partial_mat_name = 'current_only_partial.mat';
settings.final_mat_name = 'current_only_result.mat';
settings.output_dir = output_dir;

log_line(log_fid, 'START current-only MMF check mech_fixed=%.1f elec=%s Imax=%.3f', ...
    mechanical_angle_deg_fixed, mat2str(electrical_angle_deg_vals), Imax);

results = run_v_ipm_m19_torque_sweep_codex(settings);

results.electrical_angle_deg_vals = settings.elec_theta_deg_vals;
results.mechanical_angle_deg_fixed = mechanical_angle_deg_fixed;
save(summary_mat_path, 'results');

log_line(log_fid, 'COMPLETE current-only MMF check finished');

disp('Current-only MMF check complete.');
disp(table(electrical_angle_deg_vals(:), results.Ia_hist(:), results.Ib_hist(:), results.Ic_hist(:), ...
    results.F_x(:), results.F_y(:), results.torque(:), ...
    'VariableNames', {'elec_deg','Ia','Ib','Ic','Fx','Fy','torque'}));

function ensure_femm_path()
if exist('openfemm', 'file') == 2
    return;
end

candidates = {
    getenv('FEMM_MFILES')
    'C:\femm42\mfiles'
    'C:\Program Files (x86)\femm42\mfiles'
    'C:\Program Files\femm42\mfiles'
};

for idx = 1:numel(candidates)
    candidate = candidates{idx};
    if ~isempty(candidate) && isfolder(candidate)
        addpath(candidate);
        if exist('openfemm', 'file') == 2
            fprintf('Added FEMM path: %s\n', candidate);
            return;
        end
    end
end

error(['Could not find FEMM mfiles path. Set FEMM_MFILES or install FEMM in one of: ' ...
       'C:\femm42\mfiles, C:\Program Files (x86)\femm42\mfiles, C:\Program Files\femm42\mfiles']);
end

function log_line(log_fid, fmt, varargin)
msg = sprintf(fmt, varargin{:});
stamp = datestr(now, 31);
fprintf('[%s] %s\n', stamp, msg);
fprintf(log_fid, '[%s] %s\n', stamp, msg);
drawnow('limitrate');
end
