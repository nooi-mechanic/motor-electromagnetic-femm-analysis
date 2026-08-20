"""Generate rotation-safe radial and 3-seg Halbach models with 2.5 mm rotor yoke."""
from pathlib import Path
import generate_outer_rotor_36s30p_hairpin as g

g.MOTOR_OUTER_R = 72.5  # 70.0--72.5 mm = 2.5 mm, half the original 5 mm yoke
root = Path("outer_rotor_36s30p_hairpin/half_rotor_yoke_2p5mm")
root.mkdir(parents=True, exist_ok=True)
g.generate(root / "radial_half_yoke_base.fem", magnetization="radial",
           phase_current=50, current_angle_deg=90)
g.generate(root / "halbach_3seg_half_yoke_base.fem", magnetization="halbach",
           halbach_segments=3, phase_current=50, current_angle_deg=90)
