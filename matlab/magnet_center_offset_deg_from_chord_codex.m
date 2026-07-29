function offset_deg = magnet_center_offset_deg_from_chord_codex(chord_mm, magnet_center_r)
% Convert center-to-center chord length to magnet center offset angle.
%
% Geometry:
%   chord_mm = 2 * magnet_center_r * sin(offset_deg)
% so
%   offset_deg = asind(chord_mm / (2 * magnet_center_r))

if ~isscalar(chord_mm) || ~isscalar(magnet_center_r)
    error('Inputs must be scalar values.');
end

if magnet_center_r <= 0
    error('magnet_center_r must be positive.');
end

if chord_mm < 0
    error('chord_mm must be non-negative.');
end

max_chord_mm = 2 * magnet_center_r;
if chord_mm > max_chord_mm
    error('chord_mm=%.6g exceeds the maximum possible chord %.6g for r=%.6g.', ...
        chord_mm, max_chord_mm, magnet_center_r);
end

offset_deg = asind(chord_mm / (2 * magnet_center_r));
end
