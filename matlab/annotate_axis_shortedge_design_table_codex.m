function design_table = annotate_axis_shortedge_design_table_codex(base_settings, design_table)
% Add derived short-edge geometry columns and support tip-gap-driven DOE.
%
% Supported inputs per row:
% - magnet_thickness_mm
% - magnet_length_mm
% - v_angle_deg
% - optional: tip_gap_mm
% - optional: magnet_center_offset_deg
%
% Derived outputs:
% - v_included_angle_deg
% - center_chord_mm
% - tip_gap_mm
% - magnet_center_offset_deg

required_vars = {'magnet_thickness_mm', 'magnet_length_mm', 'v_angle_deg'};
missing_vars = required_vars(~ismember(required_vars, design_table.Properties.VariableNames));
if ~isempty(missing_vars)
    error('Design table is missing required columns: %s', strjoin(missing_vars, ', '));
end

n_design = height(design_table);
v_included_angle_deg = 2 * design_table.v_angle_deg;
center_chord_mm = nan(n_design, 1);
tip_gap_mm = nan(n_design, 1);
magnet_center_offset_deg = nan(n_design, 1);

has_tip_gap = ismember('tip_gap_mm', design_table.Properties.VariableNames);
has_offset = ismember('magnet_center_offset_deg', design_table.Properties.VariableNames);

for idx = 1:n_design
    magnet_length_mm = design_table.magnet_length_mm(idx);
    v_angle_deg = design_table.v_angle_deg(idx);

    if has_tip_gap
        tip_gap_mm(idx) = design_table.tip_gap_mm(idx);
        center_chord_mm(idx) = tip_gap_mm(idx) + magnet_length_mm * sind(v_angle_deg);
        magnet_center_offset_deg(idx) = magnet_center_offset_deg_from_chord_codex( ...
            center_chord_mm(idx), base_settings.magnet_center_r);
    elseif has_offset
        magnet_center_offset_deg(idx) = design_table.magnet_center_offset_deg(idx);
        center_chord_mm(idx) = magnet_center_chord_mm_from_offset_deg_codex( ...
            magnet_center_offset_deg(idx), base_settings.magnet_center_r);
        tip_gap_mm(idx) = center_chord_mm(idx) - magnet_length_mm * sind(v_angle_deg);
    else
        magnet_center_offset_deg(idx) = base_settings.magnet_center_offset_deg;
        center_chord_mm(idx) = magnet_center_chord_mm_from_offset_deg_codex( ...
            magnet_center_offset_deg(idx), base_settings.magnet_center_r);
        tip_gap_mm(idx) = center_chord_mm(idx) - magnet_length_mm * sind(v_angle_deg);
    end
end

design_table.v_included_angle_deg = v_included_angle_deg;
design_table.center_chord_mm = center_chord_mm;
design_table.tip_gap_mm = tip_gap_mm;
design_table.magnet_center_offset_deg = magnet_center_offset_deg;
end
