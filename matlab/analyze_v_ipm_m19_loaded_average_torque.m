%% analyze_v_ipm_m19_loaded_average_torque.m
% Loaded torque sweep for one mechanical revolution.
% Uses a fixed current amplitude and commutation offset, then reports the
% torque waveform, mean torque, and ripple metrics.

ensure_femm_path();

settings = default_motor_settings();
settings.Imax = 10;
settings.commutation_offset_deg = 49;

theta_deg_vals = 0:1:359;
output_dir = fullfile(pwd, 'femm_output_v_ipm_m19_loaded_average_torque');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

progress_log_path = fullfile(output_dir, 'progress_log.txt');
summary_mat_path = fullfile(output_dir, 'v_ipm_m19_loaded_average_torque_partial.mat');

log_fid = fopen(progress_log_path, 'a');
if log_fid < 0
    error('Could not open progress log: %s', progress_log_path);
end
cleanup_log = onCleanup(@() fclose(log_fid));

n_theta = numel(theta_deg_vals);
torque = nan(1, n_theta);
F_x = nan(1, n_theta);
F_y = nan(1, n_theta);
Ia_hist = nan(1, n_theta);
Ib_hist = nan(1, n_theta);
Ic_hist = nan(1, n_theta);
completed = false(1, n_theta);
error_flag = false(1, n_theta);
elapsed_sec = nan(1, n_theta);
error_message = strings(1, n_theta);

log_line(log_fid, 'START loaded torque sweep with %d cases, Imax=%.3f, commutation_offset_deg=%.3f', ...
    n_theta, settings.Imax, settings.commutation_offset_deg);

for theta_idx = 1:n_theta
    theta_deg = theta_deg_vals(theta_idx);
    fem_filename = fullfile(output_dir, sprintf('v_ipm_loaded_%03ddeg.fem', round(theta_deg)));
    ans_filename = fullfile(output_dir, sprintf('v_ipm_loaded_%03ddeg.ans', round(theta_deg)));
    step_tic = tic;

    log_line(log_fid, 'RUN theta=%.1f (%d/%d)', theta_deg, theta_idx, n_theta);

    try
        openfemm(1);
        newdocument(0);
        mi_probdef(0, 'millimeters', 'planar', 1E-8, settings.depth, 30, 0);

        build_motor_model(theta_deg, settings);

        theta_elec_rad = deg2rad(settings.pole_pairs * (theta_deg + settings.commutation_offset_deg));
        Ia = -settings.Imax * sin(theta_elec_rad);
        Ib = -settings.Imax * sin(theta_elec_rad - 2 * pi / 3);
        Ic = -settings.Imax * sin(theta_elec_rad + 2 * pi / 3);

        Ia_hist(theta_idx) = Ia;
        Ib_hist(theta_idx) = Ib;
        Ic_hist(theta_idx) = Ic;

        mi_setcurrent(settings.Coilname{1}, Ia);
        mi_setcurrent(settings.Coilname{2}, Ib);
        mi_setcurrent(settings.Coilname{3}, Ic);

        mi_saveas(fem_filename);
        log_line(log_fid, 'ANALYZE theta=%.1f fem=%s', theta_deg, fem_filename);

        mi_analyze;
        mi_loadsolution;

        mo_groupselectblock(1);
        torque(theta_idx) = mo_blockintegral(22);
        F_x(theta_idx) = mo_blockintegral(18);
        F_y(theta_idx) = mo_blockintegral(19);
        mo_clearblock;

        completed(theta_idx) = true;
        elapsed_sec(theta_idx) = toc(step_tic);
        log_line(log_fid, 'DONE theta=%.1f elapsed=%.2f s torque=%.6g ans=%s', ...
            theta_deg, elapsed_sec(theta_idx), torque(theta_idx), ans_filename);
    catch ME
        error_flag(theta_idx) = true;
        elapsed_sec(theta_idx) = toc(step_tic);
        error_message(theta_idx) = string(ME.message);
        log_line(log_fid, 'FAIL theta=%.1f elapsed=%.2f s msg=%s', ...
            theta_deg, elapsed_sec(theta_idx), ME.message);
    end

    try
        mo_close;
    catch
    end
    try
        mi_close;
    catch
    end
    try
        closefemm;
    catch
    end

    save(summary_mat_path, ...
        'theta_deg_vals', 'torque', 'F_x', 'F_y', ...
        'Ia_hist', 'Ib_hist', 'Ic_hist', ...
        'completed', 'error_flag', 'elapsed_sec', 'error_message');
end

valid_idx = completed & ~error_flag;
Fmag = hypot(F_x, F_y);
torque_mean = mean(torque(valid_idx), 'omitnan');
torque_min = min(torque(valid_idx));
torque_max = max(torque(valid_idx));
torque_pkpk = torque_max - torque_min;
torque_ripple_pct = 100 * torque_pkpk / max(abs(torque_mean), eps);

save(fullfile(output_dir, 'v_ipm_m19_loaded_average_torque.mat'), ...
    'theta_deg_vals', 'torque', 'F_x', 'F_y', 'Fmag', ...
    'Ia_hist', 'Ib_hist', 'Ic_hist', ...
    'completed', 'error_flag', 'elapsed_sec', 'error_message', ...
    'torque_mean', 'torque_min', 'torque_max', 'torque_pkpk', 'torque_ripple_pct');

log_line(log_fid, 'COMPLETE completed=%d failed=%d mean_torque=%.6g pkpk=%.6g ripple_pct=%.6g', ...
    nnz(completed), nnz(error_flag), torque_mean, torque_pkpk, torque_ripple_pct);

disp('Loaded torque sweep complete.');
fprintf('Mean torque = %.6g\n', torque_mean);
fprintf('Torque min = %.6g\n', torque_min);
fprintf('Torque max = %.6g\n', torque_max);
fprintf('Peak-to-peak torque ripple = %.6g\n', torque_pkpk);
fprintf('Torque ripple percent = %.6g\n', torque_ripple_pct);

function settings = default_motor_settings()
    settings = struct();
    settings.depth = 150;
    settings.PM = 'N35';
    settings.Core = 'M-19 Steel';
    settings.Coil = '18 AWG';
    settings.Coilname = {'Coil_A', 'Coil_B', 'Coil_C'};
    settings.PM_r = 53 / 2;
    settings.Seal = 5;
    settings.Core_ri = 64 / 2;
    settings.Core_ro = 150 / 2;
    settings.Slot_l = 20;
    settings.turns = 200;
    settings.max_segment = 10;
    settings.Core_angle = 5;
    settings.num_slots = 36;
    settings.Teeth_angle = pi / 66.95;
    settings.Teeth_length = 1;
    settings.Teeth_length2 = 1;
    settings.Arc_offset = 0.01 * pi;
    settings.shaft_r = 8;
    settings.magnet_length = 15;
    settings.magnet_thickness = 4;
    settings.v_angle_deg = 45;
    settings.magnet_center_r = settings.PM_r - 6;
    settings.magnet_center_offset_deg = 20;
    settings.pole_axes_deg = [0, 90, 180, 270];
    settings.pole_pairs = 2;
    settings.Imax = 10;
    settings.commutation_offset_deg = 49;
end

function build_motor_model(rotor_mech_angle_deg, s)
    mi_getmaterial('Air');
    mi_getmaterial(s.PM);
    mi_getmaterial(s.Coil);
    mi_getmaterial(s.Core);

    mi_drawarc(s.PM_r + s.Seal, 0, -s.PM_r - s.Seal, 0, 180, s.max_segment);
    mi_drawarc(-s.PM_r - s.Seal, 0, s.PM_r + s.Seal, 0, 180, s.max_segment);

    mi_drawarc(s.shaft_r, 0, -s.shaft_r, 0, 180, s.max_segment);
    mi_addarc(-s.shaft_r, 0, s.shaft_r, 0, 180, s.max_segment);

    magnet_specs = [];
    for pole_idx = 1:numel(s.pole_axes_deg)
        pole_axis_deg = s.pole_axes_deg(pole_idx) + rotor_mech_angle_deg;
        if mod(pole_idx, 2) == 1
            pole_magnetization_deg = mod(pole_axis_deg, 360);
        else
            pole_magnetization_deg = mod(pole_axis_deg + 180, 360);
        end

        magnet_specs = [
            magnet_specs;
            pole_axis_deg + s.magnet_center_offset_deg, s.magnet_center_r, pole_axis_deg + s.v_angle_deg, pole_magnetization_deg;
            pole_axis_deg - s.magnet_center_offset_deg, s.magnet_center_r, pole_axis_deg - s.v_angle_deg, pole_magnetization_deg
        ];
    end

    for i = 1:size(magnet_specs, 1)
        center_angle_deg = magnet_specs(i, 1);
        center_r = magnet_specs(i, 2);
        body_angle_deg = magnet_specs(i, 3);
        magnetization_deg = magnet_specs(i, 4);

        angle_rad = deg2rad(center_angle_deg);
        body_rad = deg2rad(body_angle_deg);

        cx = center_r * cos(angle_rad);
        cy = center_r * sin(angle_rad);

        along_x = cos(body_rad);
        along_y = sin(body_rad);
        normal_x = -sin(body_rad);
        normal_y = cos(body_rad);

        half_length = s.magnet_length / 2;
        half_thickness = s.magnet_thickness / 2;

        p1x = cx + along_x * half_length + normal_x * half_thickness;
        p1y = cy + along_y * half_length + normal_y * half_thickness;
        p2x = cx + along_x * half_length - normal_x * half_thickness;
        p2y = cy + along_y * half_length - normal_y * half_thickness;
        p3x = cx - along_x * half_length - normal_x * half_thickness;
        p3y = cy - along_y * half_length - normal_y * half_thickness;
        p4x = cx - along_x * half_length + normal_x * half_thickness;
        p4y = cy - along_y * half_length + normal_y * half_thickness;

        mi_drawline(p1x, p1y, p2x, p2y);
        mi_drawline(p2x, p2y, p3x, p3y);
        mi_drawline(p3x, p3y, p4x, p4y);
        mi_drawline(p4x, p4y, p1x, p1y);

        mi_addblocklabel(cx, cy);
        mi_selectlabel(cx, cy);
        mi_setblockprop(s.PM, 1, 0, 0, magnetization_deg, 1, 0);
        mi_clearselected;
    end

    rotor_core_label_r = s.shaft_r + 1;
    mi_addblocklabel(rotor_core_label_r, 0);
    mi_selectlabel(rotor_core_label_r, 0);
    mi_setblockprop(s.Core, 1, 0, 0, 0, 1, 0);
    mi_clearselected;

    mi_addblocklabel(0, 0);
    mi_selectlabel(0, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
    mi_clearselected;

    mi_drawarc(s.Core_ro, 0, -s.Core_ro, 0, 180, s.max_segment);
    mi_addarc(-s.Core_ro, 0, s.Core_ro, 0, 180, s.max_segment);

    for i = 0:s.num_slots
        h = (i - 1) * 2 * pi / 180;
        j = i * 2 * pi / 180;
        k = (i + 1) * 2 * pi / 180;
        L = (i + 2) * 2 * pi / 180;
        if mod(i, 2) == 1
            mi_drawarc(s.Core_ri * cos(h * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle - s.Teeth_angle), s.Core_ri * cos(j * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle + s.Teeth_angle), s.Core_angle + s.Teeth_angle * 2, s.max_segment);
            mi_drawline(s.Core_ri * cos(h * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * cos(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(h * s.Core_angle - s.Teeth_angle));
            mi_drawline(s.Core_ri * cos(j * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * cos(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(j * s.Core_angle + s.Teeth_angle));
            mi_drawline((s.Core_ri + s.Teeth_length) * cos(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(h * s.Core_angle - s.Teeth_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(h * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(h * s.Core_angle));
            mi_drawline((s.Core_ri + s.Teeth_length) * cos(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length) * sin(j * s.Core_angle + s.Teeth_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle));
            mi_drawline((s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(j * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(j * s.Core_angle - s.Arc_offset));
        else
            mi_drawarc((s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(k * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(k * s.Core_angle - s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(L * s.Core_angle + s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(L * s.Core_angle + s.Arc_offset), 180, s.max_segment);
            mi_drawarc(s.Core_ri * cos(h * s.Core_angle + s.Teeth_angle), s.Core_ri * sin(h * s.Core_angle + s.Teeth_angle), s.Core_ri * cos(j * s.Core_angle - s.Teeth_angle), s.Core_ri * sin(j * s.Core_angle - s.Teeth_angle), s.Core_angle - s.Teeth_angle * 2, s.max_segment);
            mi_drawline((s.Core_ri + s.Teeth_length + s.Teeth_length2) * cos(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2) * sin(j * s.Core_angle), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * cos(j * s.Core_angle + s.Arc_offset), (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l) * sin(j * s.Core_angle + s.Arc_offset));
        end
    end

    stator_backiron_r = (s.Core_ro + (s.Core_ri + s.Teeth_length + s.Teeth_length2 + s.Slot_l)) / 2;
    mi_addblocklabel(stator_backiron_r, 0);
    mi_selectlabel(stator_backiron_r, 0);
    mi_setblockprop(s.Core, 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    airgap_label_r = (s.PM_r + s.Seal + s.Core_ri) / 2;
    mi_addblocklabel(airgap_label_r, 0);
    mi_selectlabel(airgap_label_r, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    mi_addblocklabel(s.PM_r * 5, 0);
    mi_selectlabel(s.PM_r * 5, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    slot_center_deg = 15:20:355;
    slot_label_radius = (s.Core_ri + s.Teeth_length2 + s.Slot_l) * cosd(5);
    slot_circuit_names = { ...
        s.Coilname{1}, s.Coilname{3}, s.Coilname{2}, s.Coilname{1}, s.Coilname{3}, s.Coilname{2}, ...
        s.Coilname{1}, s.Coilname{3}, s.Coilname{2}, s.Coilname{1}, s.Coilname{3}, s.Coilname{2}, ...
        s.Coilname{1}, s.Coilname{3}, s.Coilname{2}, s.Coilname{1}, s.Coilname{3}, s.Coilname{2}};
    slot_turn_signs = [ ...
         s.turns, -s.turns,  s.turns, -s.turns,  s.turns, -s.turns, ...
         s.turns, -s.turns,  s.turns, -s.turns,  s.turns, -s.turns, ...
         s.turns, -s.turns,  s.turns, -s.turns,  s.turns, -s.turns];

    for i = 1:numel(s.Coilname)
        mi_addcircprop(s.Coilname{i}, 0, 1);
    end

    for slot_idx = 1:numel(slot_center_deg)
        angle_deg = slot_center_deg(slot_idx);
        x = slot_label_radius * cosd(angle_deg);
        y = slot_label_radius * sind(angle_deg);
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(s.Coil, 1, 0, slot_circuit_names{slot_idx}, 0, 2, slot_turn_signs(slot_idx));
        mi_clearselected;
    end

    mi_makeABC(7, s.Core_ro * 2, 0, 0, 0);
end

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
