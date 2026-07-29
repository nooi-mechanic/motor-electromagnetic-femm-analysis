function chord_mm = magnet_center_chord_mm_from_offset_deg_codex(offset_deg, magnet_center_r)
% Convert magnet center offset angle to center-to-center chord length.
%
% Geometry:
%   chord_mm = 2 * magnet_center_r * sin(offset_deg)

if ~isscalar(offset_deg) || ~isscalar(magnet_center_r)
    error('Inputs must be scalar values.');
end

if magnet_center_r <= 0
    error('magnet_center_r must be positive.');
end

chord_mm = 2 * magnet_center_r * sind(offset_deg);
end
