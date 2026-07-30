function result = simulate_v_ipm_theta_sweep(params, opts)
% simulate_v_ipm_theta_sweep
% Build a V-IPM FEMM model, rotate the rotor through theta samples,
% solve each operating point, and return force / torque / airgap data.

    if nargin < 1 || isempty(params)
        params = default_v_ipm_params();
    end
    if nargin < 2
        opts = struct();
    end

    opts = apply_option_defaults(opts, params);

    if ~exist(opts.output_dir, 'dir')
        mkdir(opts.output_dir);
    end

    base_fem_filename = fullfile(opts.output_dir, sprintf('%s_base.fem', opts.case_name));

    openfemm(1);
    newdocument(0);
    mi_probdef(0, 'millimeters', 'planar', 1E-8, params.depth, 30, 0);

    define_materials(params);
    build_v_ipm_geometry(params);

    mi_makeABC(7, params.PM_r * 20, 0, 0, 0);
    mi_saveas(base_fem_filename);
    mi_close;

    theta_deg_vals = opts.theta_deg_vals(:).';
    torque = zeros(size(theta_deg_vals));
    F_x = zeros(size(theta_deg_vals));
    F_y = zeros(size(theta_deg_vals));
    tangential_force = zeros(size(theta_deg_vals));
    Ia_hist = zeros(size(theta_deg_vals));
    Ib_hist = zeros(size(theta_deg_vals));
    Ic_hist = zeros(size(theta_deg_vals));

    if opts.sample_airgap
        airgap_theta_deg = opts.airgap_theta_deg(:).';
        airgap_Br = zeros(numel(theta_deg_vals), numel(airgap_theta_deg));
        airgap_Bt = zeros(numel(theta_deg_vals), numel(airgap_theta_deg));
        airgap_tangential_force = zeros(size(theta_deg_vals));
    else
        airgap_theta_deg = [];
        airgap_Br = [];
        airgap_Bt = [];
        airgap_tangential_force = [];
    end

    for theta_idx = 1:numel(theta_deg_vals)
        theta_deg = theta_deg_vals(theta_idx);
        fem_filename = fullfile(opts.output_dir, sprintf('%s_%03ddeg.fem', opts.case_name, round(theta_deg)));

        opendocument(base_fem_filename);

        mi_selectgroup(1);
        mi_moverotate(0, 0, theta_deg);
        mi_clearselected;

        theta_elec_deg = opts.rotation_sign * opts.pole_pairs * theta_deg + opts.commutation_offset_deg;
        theta_elec_rad = deg2rad(theta_elec_deg);

        Ia = -opts.Imax * sin(theta_elec_rad);
        Ib = -opts.Imax * sin(theta_elec_rad - 2*pi/3);
        Ic = -opts.Imax * sin(theta_elec_rad + 2*pi/3);

        Ia_hist(theta_idx) = Ia;
        Ib_hist(theta_idx) = Ib;
        Ic_hist(theta_idx) = Ic;

        mi_setcurrent(params.Coilname{1}, Ia);
        mi_setcurrent(params.Coilname{2}, Ib);
        mi_setcurrent(params.Coilname{3}, Ic);

        mi_saveas(fem_filename);
        mi_analyze;
        mi_loadsolution;

        mo_groupselectblock(1);
        torque(theta_idx) = mo_blockintegral(22);
        F_x(theta_idx) = mo_blockintegral(18);
        F_y(theta_idx) = mo_blockintegral(19);
        mo_clearblock;

        tangential_force(theta_idx) = torque(theta_idx) / (opts.effective_radius_mm / 1000);

        if opts.sample_airgap
            [airgap_Br(theta_idx,:), airgap_Bt(theta_idx,:)] = ...
                sample_airgap_circle(opts.airgap_radius_mm, airgap_theta_deg);
            airgap_tangential_force(theta_idx) = estimate_airgap_tangential_force( ...
                airgap_Br(theta_idx,:), airgap_Bt(theta_idx,:), ...
                opts.airgap_radius_mm, params.depth);
        end

        mo_close;
        mi_close;
    end

    metrics = summarize_theta_sweep(theta_deg_vals, torque, tangential_force, F_x, F_y);

    if ~isempty(airgap_tangential_force)
        metrics.mean_airgap_tangential_force = mean(airgap_tangential_force);
        metrics.airgap_tangential_force_pp = max(airgap_tangential_force) - min(airgap_tangential_force);
    else
        metrics.mean_airgap_tangential_force = NaN;
        metrics.airgap_tangential_force_pp = NaN;
    end

    result = struct();
    result.params = params;
    result.opts = opts;
    result.theta_deg_vals = theta_deg_vals;
    result.torque = torque;
    result.tangential_force = tangential_force;
    result.F_x = F_x;
    result.F_y = F_y;
    result.Ia_hist = Ia_hist;
    result.Ib_hist = Ib_hist;
    result.Ic_hist = Ic_hist;
    result.airgap_theta_deg = airgap_theta_deg;
    result.airgap_Br = airgap_Br;
    result.airgap_Bt = airgap_Bt;
    result.airgap_tangential_force = airgap_tangential_force;
    result.metrics = metrics;

    save(fullfile(opts.output_dir, sprintf('%s_results.mat', opts.case_name)), 'result');
end

function params = default_v_ipm_params()
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

function opts = apply_option_defaults(opts, params)
    if ~isfield(opts, 'case_name'), opts.case_name = 'v_ipm_case'; end
    if ~isfield(opts, 'output_dir'), opts.output_dir = fullfile(pwd, 'femm_output_v_ipm_cases'); end
    if ~isfield(opts, 'theta_deg_vals'), opts.theta_deg_vals = 0:1:359; end
    if ~isfield(opts, 'Imax'), opts.Imax = 0; end
    if ~isfield(opts, 'pole_pairs'), opts.pole_pairs = 2; end
    if ~isfield(opts, 'rotation_sign'), opts.rotation_sign = 1; end
    if ~isfield(opts, 'commutation_offset_deg'), opts.commutation_offset_deg = 0; end
    if ~isfield(opts, 'effective_radius_mm'), opts.effective_radius_mm = (params.PM_r + params.Seal + params.Core_ri) / 2; end
    if ~isfield(opts, 'sample_airgap'), opts.sample_airgap = true; end
    if ~isfield(opts, 'airgap_radius_mm'), opts.airgap_radius_mm = (params.PM_r + params.Seal + params.Core_ri) / 2; end
    if ~isfield(opts, 'airgap_theta_deg'), opts.airgap_theta_deg = linspace(0, 359, 360); end
end

function define_materials(params)
    mi_addmaterial(params.Core, 4000, 4000, 0, 1.8e6, 0.0, 0.35, 1.5, 0.95, 0, 0, 0, 0, 0);
    bh_core = [
        0, 0;
        100, 0.005;
        500, 0.05;
        1000, 0.15;
        2000, 0.30;
        3000, 0.45;
        5000, 0.70;
        8000, 1.00;
        12000, 1.25;
        16000, 1.40;
        20000, 1.45;
        25000, 1.47;
        30000, 1.48;
        35000, 1.49;
        40000, 1.50
    ];
    for i = 1:size(bh_core,1)
        mi_addbhpoint(params.Core, bh_core(i,2), bh_core(i,1));
    end

    mi_addmaterial(params.Sealing, ...
        1.02, ...
        1.02, ...
        0, ...
        0, ...
        0.8, ...
        0, ...
        0, ...
        1, ...
        0, ...
        0, ...
        0, ...
        1, ...
        0);

    mi_getmaterial('Air');
    mi_getmaterial(params.PM);
    mi_getmaterial(params.Coil);
end

function build_v_ipm_geometry(params)
    mi_drawarc(params.PM_r + params.Seal, 0, -params.PM_r - params.Seal, 0, 180, params.max_segment);
    mi_drawarc(-params.PM_r - params.Seal, 0, params.PM_r + params.Seal, 0, 180, params.max_segment);

    mi_drawarc(params.shaft_r, 0, -params.shaft_r, 0, 180, params.max_segment);
    mi_addarc(-params.shaft_r, 0, params.shaft_r, 0, 180, params.max_segment);

    pole_axes_deg = [0, 90, 180, 270];
    magnet_specs = [];

    for pole_idx = 1:numel(pole_axes_deg)
        pole_axis_deg = pole_axes_deg(pole_idx);
        pole_magnetization_deg = mod(180 - pole_axis_deg, 360);

        magnet_specs = [
            magnet_specs;
            pole_axis_deg + params.magnet_center_offset_deg, params.magnet_center_r, pole_axis_deg + params.v_angle_deg, pole_magnetization_deg;
            pole_axis_deg - params.magnet_center_offset_deg, params.magnet_center_r, pole_axis_deg - params.v_angle_deg, pole_magnetization_deg
        ];
    end

    for i = 1:size(magnet_specs,1)
        center_angle_deg = magnet_specs(i,1);
        center_r = magnet_specs(i,2);
        body_angle_deg = magnet_specs(i,3);
        magnetization_deg = magnet_specs(i,4);

        angle_rad = deg2rad(center_angle_deg);
        body_rad = deg2rad(body_angle_deg);

        cx = center_r * cos(angle_rad);
        cy = center_r * sin(angle_rad);

        along_x = cos(body_rad);
        along_y = sin(body_rad);
        normal_x = -sin(body_rad);
        normal_y = cos(body_rad);

        half_length = params.magnet_length / 2;
        half_thickness = params.magnet_thickness / 2;

        p1x = cx + along_x * half_length + normal_x * half_thickness;
        p1y = cy + along_y * half_length + normal_y * half_thickness;
        p2x = cx + along_x * half_length - normal_x * half_thickness;
        p2y = cy + along_y * half_length - normal_y * half_thickness;
        p3x = cx - along_x * half_length - normal_x * half_thickness;
        p3y = cy - along_y * half_length - normal_y * half_thickness;
        p4x = cx - along_x * half_length + normal_x * half_thickness;
        p4y = cy - along_y * half_length + normal_y * half_thickness;

        mi_drawline(p1x,p1y,p2x,p2y);
        mi_drawline(p2x,p2y,p3x,p3y);
        mi_drawline(p3x,p3y,p4x,p4y);
        mi_drawline(p4x,p4y,p1x,p1y);

        mi_addblocklabel(cx, cy);
        mi_selectlabel(cx, cy);
        mi_setblockprop(params.PM, 1, 0, 0, magnetization_deg, 1, 0);
        mi_clearselected;
    end

    mi_addblocklabel(0, params.shaft_r + 5);
    mi_selectlabel(0, params.shaft_r + 5);
    mi_setblockprop(params.Core, 1, 0, 0, 0, 1, 0);
    mi_clearselected;

    mi_addblocklabel(0, 0);
    mi_selectlabel(0, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 1, 0);
    mi_clearselected;

    mi_selectcircle(0, 0, params.PM_r + params.Seal + 1, 4);
    mi_setgroup(1);
    mi_clearselected;

    mi_drawarc(params.Core_ro, 0, -params.Core_ro, 0, 180, params.max_segment);
    mi_addarc(-params.Core_ro, 0, params.Core_ro, 0, 180, params.max_segment);

    for i = 0:params.num_slots
        h = (i-1)*2*pi/180;
        j = i*2*pi/180;
        k = (i+1)*2*pi/180;
        L = (i+2)*2*pi/180;
        if mod(i,2) == 1
            mi_drawarc(params.Core_ri*cos(h*params.Core_angle-params.Teeth_angle), params.Core_ri*sin(h*params.Core_angle-params.Teeth_angle), params.Core_ri*cos(j*params.Core_angle+params.Teeth_angle), params.Core_ri*sin(j*params.Core_angle+params.Teeth_angle), params.Core_angle+params.Teeth_angle*2, params.max_segment);
            mi_drawline(params.Core_ri*cos(h*params.Core_angle-params.Teeth_angle), params.Core_ri*sin(h*params.Core_angle-params.Teeth_angle), (params.Core_ri+params.Teeth_length)*cos(h*params.Core_angle-params.Teeth_angle), (params.Core_ri+params.Teeth_length)*sin(h*params.Core_angle-params.Teeth_angle));
            mi_drawline(params.Core_ri*cos(j*params.Core_angle+params.Teeth_angle), params.Core_ri*sin(j*params.Core_angle+params.Teeth_angle), (params.Core_ri+params.Teeth_length)*cos(j*params.Core_angle+params.Teeth_angle), (params.Core_ri+params.Teeth_length)*sin(j*params.Core_angle+params.Teeth_angle));
            mi_drawline((params.Core_ri+params.Teeth_length)*cos(h*params.Core_angle-params.Teeth_angle), (params.Core_ri+params.Teeth_length)*sin(h*params.Core_angle-params.Teeth_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*cos(h*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*sin(h*params.Core_angle));
            mi_drawline((params.Core_ri+params.Teeth_length)*cos(j*params.Core_angle+params.Teeth_angle), (params.Core_ri+params.Teeth_length)*sin(j*params.Core_angle+params.Teeth_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*cos(j*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*sin(j*params.Core_angle));
            mi_drawline((params.Core_ri+params.Teeth_length+params.Teeth_length2)*cos(j*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*sin(j*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*cos(j*params.Core_angle-params.Arc_offset), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*sin(j*params.Core_angle-params.Arc_offset));
        else
            mi_drawarc((params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*cos(k*params.Core_angle-params.Arc_offset), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*sin(k*params.Core_angle-params.Arc_offset), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*cos(L*params.Core_angle+params.Arc_offset), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*sin(L*params.Core_angle+params.Arc_offset), 180, params.max_segment);
            mi_drawarc(params.Core_ri*cos(h*params.Core_angle+params.Teeth_angle), params.Core_ri*sin(h*params.Core_angle+params.Teeth_angle), params.Core_ri*cos(j*params.Core_angle-params.Teeth_angle), params.Core_ri*sin(j*params.Core_angle-params.Teeth_angle), params.Core_angle-params.Teeth_angle*2, params.max_segment);
            mi_drawline((params.Core_ri+params.Teeth_length+params.Teeth_length2)*cos(j*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2)*sin(j*params.Core_angle), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*cos(j*params.Core_angle+params.Arc_offset), (params.Core_ri+params.Teeth_length+params.Teeth_length2+params.Slot_l)*sin(j*params.Core_angle+params.Arc_offset));
        end
    end

    mi_addblocklabel(params.Core_ro-0.1, 0);
    mi_selectlabel(params.Core_ro-0.1, 0);
    mi_setblockprop(params.Core, 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    mi_addblocklabel((params.PM_r + params.Seal + params.Core_ri)/2, 0);
    mi_selectlabel((params.PM_r + params.Seal + params.Core_ri)/2, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    mi_addblocklabel(params.PM_r*5, 0);
    mi_selectlabel(params.PM_r*5, 0);
    mi_setblockprop('Air', 1, 0, 0, 0, 2, 0);
    mi_clearselected;

    for i = 1:3
        h = (i-1)*2*pi/180;
        j = i*2*pi/180;
        k = (i+1)*2*pi/180;

        mi_addcircprop(params.Coilname{i}, 0, 1);

        P = -3*pi/9;
        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle+P)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle+P))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle+P)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle+P))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{3}, 0, 2, -params.turns);
        mi_clearselected;

        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{1}, 0, 2, params.turns);
        mi_clearselected;

        P = 3*pi/9;
        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle+P)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle+P))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle+P)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle+P))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{2}, 0, 2, params.turns);
        mi_clearselected;

        copy_angle = pi-P;
        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle+copy_angle))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle+copy_angle))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{3}, 0, 2, params.turns);
        mi_clearselected;

        copy_angle = pi;
        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle+copy_angle))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle+copy_angle))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{1}, 0, 2, -params.turns);
        mi_clearselected;

        copy_angle = pi+P;
        x = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*cos((k+h)*params.Core_angle+copy_angle))/2;
        y = ((params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((j+h)*params.Core_angle+copy_angle)+(params.Core_ri+params.Teeth_length2+params.Slot_l)*sin((k+h)*params.Core_angle+copy_angle))/2;
        mi_addblocklabel(x, y);
        mi_selectlabel(x, y);
        mi_setblockprop(params.Coil, 1, 0, params.Coilname{2}, 0, 2, -params.turns);
        mi_clearselected;
    end
end

function [Br_row, Bt_row] = sample_airgap_circle(radius_mm, theta_deg_row)
    Br_row = zeros(size(theta_deg_row));
    Bt_row = zeros(size(theta_deg_row));

    for idx = 1:numel(theta_deg_row)
        theta_deg = theta_deg_row(idx);
        x = radius_mm * cosd(theta_deg);
        y = radius_mm * sind(theta_deg);
        [~, Bx, By] = mo_getpointvalues(x, y);

        c = cosd(theta_deg);
        s = sind(theta_deg);
        Br_row(idx) = Bx * c + By * s;
        Bt_row(idx) = -Bx * s + By * c;
    end
end

function metrics = summarize_theta_sweep(theta_deg_vals, torque, tangential_force, F_x, F_y)
    metrics = struct();
    metrics.theta_deg_vals = theta_deg_vals;
    metrics.mean_torque = mean(torque);
    metrics.torque_pp = max(torque) - min(torque);
    metrics.torque_rms = sqrt(mean(torque.^2));
    metrics.mean_thrust = mean(tangential_force);
    metrics.thrust_pp = max(tangential_force) - min(tangential_force);
    metrics.thrust_rms = sqrt(mean(tangential_force.^2));
    metrics.mean_F_x = mean(F_x);
    metrics.F_x_pp = max(F_x) - min(F_x);
    metrics.mean_F_y = mean(F_y);
    metrics.F_y_pp = max(F_y) - min(F_y);
end

function force_t = estimate_airgap_tangential_force(Br_row, Bt_row, radius_mm, depth_mm)
    mu0 = 4*pi*1e-7;
    radius_m = radius_mm / 1000;
    depth_m = depth_mm / 1000;
    theta_rad = linspace(0, 2*pi, numel(Br_row) + 1);
    theta_rad(end) = [];
    tangential_stress = (Br_row .* Bt_row) / mu0;
    force_density_integrand = tangential_stress * radius_m * depth_m;
    force_t = trapz(theta_rad, force_density_integrand);
end
