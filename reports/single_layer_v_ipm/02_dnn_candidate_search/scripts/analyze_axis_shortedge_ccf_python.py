"""Python/FEMM port of the axis-parallel-short-edge loaded sweep.

This is intentionally separate from ``generate_v_ipm_motor.py``.  It reuses
that file's stator/material helpers while replacing only the rotor geometry
and sweep definition under active conversion.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import femm
import generate_v_ipm_motor as base


def define_axis_shortedge_materials() -> None:
    """Load the same library materials used by the MATLAB model."""
    femm.mi_getmaterial("Air")
    femm.mi_getmaterial("N35")
    femm.mi_getmaterial("M-19 Steel")
    femm.mi_getmaterial("18 AWG")


def add_axis_shortedge_windings() -> None:
    """Apply the MATLAB 18-slot/4-pole/3-phase single-layer winding."""
    for circuit_name in base.COIL_NAMES:
        femm.mi_addcircprop(circuit_name, 0, 1)

    slot_center_deg = range(15, 356, 20)
    slot_label_radius = (
        base.CORE_RI + base.TEETH_LENGTH2 + base.SLOT_L
    ) * math.cos(math.radians(5))
    a, b, c = base.COIL_NAMES
    circuits = (
        a, a, c,
        a, b, a,
        c, c, b,
        c, a, c,
        b, b, a,
        b, c, b,
    )
    turns = (
        base.TURNS, base.TURNS, -base.TURNS,
        -base.TURNS, base.TURNS, -base.TURNS,
        base.TURNS, base.TURNS, -base.TURNS,
        -base.TURNS, base.TURNS, -base.TURNS,
        base.TURNS, base.TURNS, -base.TURNS,
        -base.TURNS, base.TURNS, -base.TURNS,
    )
    for angle_deg, circuit, signed_turns in zip(
        slot_center_deg, circuits, turns
    ):
        x, y = base.polar(
            slot_label_radius, math.radians(angle_deg)
        )
        base.add_block(
            x,
            y,
            base.COIL,
            circuit=circuit,
            group=2,
            turns=signed_turns,
        )


def polygon(
    center_angle_deg: float,
    body_angle_deg: float,
    pole_axis_deg: float,
    length_mm: float,
    normal_thickness_mm: float,
    side_sign: float,
) -> tuple[tuple[float, float], ...]:
    """Create a parallelogram whose short edge is parallel to the pole axis."""
    sin_v = abs(math.sin(math.radians(body_angle_deg - pole_axis_deg)))
    if sin_v < 1e-12:
        raise ValueError("V angle must not be zero")

    center = base.polar(base.MAGNET_CENTER_R, math.radians(center_angle_deg))
    long_unit = base.polar(1, math.radians(body_angle_deg))
    short_unit = base.polar(1, math.radians(pole_axis_deg))
    short_length = normal_thickness_mm / sin_v
    long_vec = tuple(length_mm * value for value in long_unit)
    short_vec = tuple(side_sign * short_length * value for value in short_unit)

    return tuple(
        (
            center[0] + long_sign * long_vec[0] / 2
            + short_sign * short_vec[0] / 2,
            center[1] + long_sign * long_vec[1] / 2
            + short_sign * short_vec[1] / 2,
        )
        for long_sign, short_sign in ((-1, -1), (1, -1), (1, 1), (-1, 1))
    )


def center_offset_deg(
    tip_gap_mm: float, length_mm: float, v_angle_deg: float
) -> float:
    center_chord = tip_gap_mm + length_mm * math.sin(
        math.radians(v_angle_deg)
    )
    ratio = center_chord / (2 * base.MAGNET_CENTER_R)
    if not 0 <= ratio <= 1:
        raise ValueError("Tip gap produces an impossible center chord")
    return math.degrees(math.asin(ratio))


def make_draw_rotor(
    length_mm: float,
    normal_thickness_mm: float,
    v_angle_deg: float,
    tip_gap_mm: float,
    center_offset_override_deg: float | None = None,
):
    offset_deg = (
        center_offset_override_deg
        if center_offset_override_deg is not None
        else center_offset_deg(tip_gap_mm, length_mm, v_angle_deg)
    )

    def draw_rotor(rotor_mech_angle_deg: float = 0) -> None:
        rotor_outer_r = base.PM_R + base.SEAL
        femm.mi_drawarc(
            rotor_outer_r, 0, -rotor_outer_r, 0, 180, base.MAX_SEGMENT
        )
        femm.mi_drawarc(
            -rotor_outer_r, 0, rotor_outer_r, 0, 180, base.MAX_SEGMENT
        )
        femm.mi_drawarc(
            base.SHAFT_R, 0, -base.SHAFT_R, 0, 180, base.MAX_SEGMENT
        )
        femm.mi_addarc(
            -base.SHAFT_R, 0, base.SHAFT_R, 0, 180, base.MAX_SEGMENT
        )

        for pole_index, nominal_axis in enumerate((0, 90, 180, 270)):
            pole_axis = nominal_axis + rotor_mech_angle_deg
            magnetization = (
                pole_axis if pole_index % 2 == 0 else pole_axis + 180
            ) % 360
            for side_sign in (1, -1):
                points = polygon(
                    pole_axis + side_sign * offset_deg,
                    pole_axis + side_sign * v_angle_deg,
                    pole_axis,
                    length_mm,
                    normal_thickness_mm,
                    side_sign,
                )
                for start, end in zip(points, points[1:] + points[:1]):
                    femm.mi_drawline(*start, *end)
                cx = sum(point[0] for point in points) / 4
                cy = sum(point[1] for point in points) / 4
                base.add_block(
                    cx,
                    cy,
                    base.PM,
                    magnetization_deg=magnetization,
                    group=1,
                )

        rotor_core_label_r = base.SHAFT_R + 0.1
        base.add_block(rotor_core_label_r, 0, base.CORE, group=1)
        base.add_block(0, 0, "Air", group=1)
        femm.mi_selectcircle(0, 0, rotor_outer_r + 1, 4)
        femm.mi_setgroup(1)
        femm.mi_clearselected()

    return draw_rotor


def angles(start: float, stop: float, step: float):
    count = math.floor((stop - start) / step + 1e-12)
    for index in range(count + 1):
        yield start + index * step


def run_sweep(
    output_dir: Path,
    theta_values,
    current_max: float,
    commutation_offset_deg: float,
    rotor_initial_angle_deg: float = -10,
) -> Path:
    rows = []
    result = output_dir / "axis_shortedge_loaded_sweep.csv"
    for theta_deg in theta_values:
        # Match the MATLAB study: rebuild every angle so magnet geometry and
        # magnetization direction are both evaluated at the rotated position.
        base.build_base_model(
            output_dir,
            rotor_mech_angle_deg=rotor_initial_angle_deg + theta_deg,
        )

        theta_e = math.radians(
            base.POLE_PAIRS * (theta_deg + commutation_offset_deg)
        )
        currents = (
            -current_max * math.sin(theta_e),
            -current_max * math.sin(theta_e - 2 * math.pi / 3),
            -current_max * math.sin(theta_e + 2 * math.pi / 3),
        )
        for name, current in zip(base.COIL_NAMES, currents):
            femm.mi_setcurrent(name, current)

        femm.mi_analyze()
        femm.mi_loadsolution()
        femm.mo_groupselectblock(1)
        rows.append(
            {
                "theta_deg": theta_deg,
                "torque_Nm": femm.mo_blockintegral(22),
                "force_x_N": femm.mo_blockintegral(18),
                "force_y_N": femm.mo_blockintegral(19),
            }
        )
        femm.mo_clearblock()
        femm.mo_close()
        femm.mi_close()

        with result.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)
    return result


def summarize_torque(rows: list[dict[str, float]]) -> dict[str, float]:
    torque = [row["torque_Nm"] for row in rows]
    torque_mean = sum(torque) / len(torque)
    torque_min = min(torque)
    torque_max = max(torque)
    torque_pkpk = torque_max - torque_min
    return {
        "loaded_torque_mean_Nm": torque_mean,
        "loaded_torque_min_Nm": torque_min,
        "loaded_torque_max_Nm": torque_max,
        "loaded_torque_pkpk_Nm": torque_pkpk,
        "loaded_torque_ripple_pct": (
            100 * torque_pkpk / abs(torque_mean)
            if abs(torque_mean) > 1e-15
            else math.nan
        ),
    }


def solve_loaded_design(
    design: dict[str, str],
    root_dir: Path,
    theta_start: float,
    theta_stop: float,
    theta_step: float,
    current_max: float,
    commutation_offset_deg: float,
) -> dict[str, float | int]:
    run = int(float(design["run"]))
    length = float(design["magnet_length_mm"])
    thickness = float(design["magnet_thickness_mm"])
    v_angle = float(design["v_angle_deg"])
    tip_gap = float(design["tip_gap_mm"])
    offset_override = design.get("magnet_center_offset_deg")
    offset_override = (
        float(offset_override) if offset_override not in (None, "") else None
    )
    case_dir = root_dir / f"run_{run:03d}"
    case_dir.mkdir(parents=True, exist_ok=True)

    base.draw_rotor = make_draw_rotor(
        length,
        thickness,
        v_angle,
        tip_gap,
        center_offset_override_deg=offset_override,
    )
    sweep_path = run_sweep(
        case_dir,
        angles(theta_start, theta_stop, theta_step),
        current_max,
        commutation_offset_deg,
    )
    with sweep_path.open(newline="", encoding="utf-8") as handle:
        rows = [
            {key: float(value) for key, value in row.items()}
            for row in csv.DictReader(handle)
        ]

    summary: dict[str, float | int] = {
        "run": run,
        "magnet_thickness_mm": thickness,
        "magnet_length_mm": length,
        "v_angle_deg": v_angle,
        "v_included_angle_deg": 2 * v_angle,
        "tip_gap_mm": tip_gap,
        "magnet_center_offset_deg": (
            offset_override
            if offset_override is not None
            else center_offset_deg(tip_gap, length, v_angle)
        ),
        "theta_start_deg": theta_start,
        "theta_stop_deg": theta_stop,
        "theta_step_deg": theta_step,
        "current_peak_A": current_max,
        "commutation_offset_deg": commutation_offset_deg,
        "completed_points": len(rows),
    }
    summary.update(summarize_torque(rows))
    return summary


def run_ccf(
    design_csv: Path,
    output_dir: Path,
    theta_start: float,
    theta_stop: float,
    theta_step: float,
    current_max: float,
    commutation_offset_deg: float,
    design_limit: int | None = None,
) -> Path:
    with design_csv.open(newline="", encoding="utf-8-sig") as handle:
        designs = list(csv.DictReader(handle))
    if design_limit is not None:
        designs = designs[:design_limit]
    required = {
        "run",
        "magnet_thickness_mm",
        "magnet_length_mm",
        "v_angle_deg",
        "tip_gap_mm",
    }
    if not designs or not required.issubset(designs[0]):
        raise ValueError(
            f"Design CSV must contain: {', '.join(sorted(required))}"
        )

    summaries = []
    partial_path = output_dir / "axis_shortedge_ccf_summary_partial.csv"
    for index, design in enumerate(designs, start=1):
        print(
            f"CCF {index}/{len(designs)} run={design['run']} "
            f"t={design['magnet_thickness_mm']} "
            f"L={design['magnet_length_mm']} "
            f"v={design['v_angle_deg']} gap={design['tip_gap_mm']}"
        )
        summary = solve_loaded_design(
            design,
            output_dir,
            theta_start,
            theta_stop,
            theta_step,
            current_max,
            commutation_offset_deg,
        )
        summaries.append(summary)
        with partial_path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=summaries[0].keys())
            writer.writeheader()
            writer.writerows(summaries)
        print(
            f"  mean={summary['loaded_torque_mean_Nm']:.6g} Nm, "
            f"pkpk={summary['loaded_torque_pkpk_Nm']:.6g} Nm, "
            f"ripple={summary['loaded_torque_ripple_pct']:.3f}%"
        )

    final_path = output_dir / "axis_shortedge_ccf_summary.csv"
    partial_path.replace(final_path)
    return final_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path("femm_output_axis_shortedge_python"))
    parser.add_argument("--magnet-length", type=float, default=15)
    parser.add_argument("--magnet-thickness", type=float, default=4)
    parser.add_argument("--v-angle", type=float, default=45)
    parser.add_argument("--tip-gap", type=float, default=2.5)
    parser.add_argument("--sweep", action="store_true")
    parser.add_argument(
        "--design-csv",
        type=Path,
        help="Run every 4-factor CCF design in this CSV.",
    )
    parser.add_argument(
        "--design-limit",
        type=int,
        default=None,
        help="Run only the first N CSV rows for a short verification.",
    )
    parser.add_argument("--theta-start", type=float, default=0)
    parser.add_argument("--theta-stop", type=float, default=29)
    parser.add_argument("--theta-step", type=float, default=1)
    parser.add_argument("--current-max", type=float, default=10)
    parser.add_argument("--commutation-offset", type=float, default=30)
    args = parser.parse_args()
    if args.theta_step <= 0:
        raise ValueError("theta-step must be positive")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    base.draw_rotor = make_draw_rotor(
        args.magnet_length,
        args.magnet_thickness,
        args.v_angle,
        args.tip_gap,
    )
    base.CORE = "M-19 Steel"
    base.define_materials = define_axis_shortedge_materials
    base.add_windings = add_axis_shortedge_windings
    try:
        femm.openfemm(1)
        if args.design_csv:
            result = run_ccf(
                args.design_csv,
                args.output_dir,
                args.theta_start,
                args.theta_stop,
                args.theta_step,
                args.current_max,
                args.commutation_offset,
                args.design_limit,
            )
            print(f"Created CCF summary: {result}")
        else:
            base_file = base.build_base_model(
                args.output_dir, rotor_mech_angle_deg=-10
            )
            print(f"Created base model: {base_file}")
        if args.sweep and not args.design_csv:
            result = run_sweep(
                args.output_dir,
                angles(args.theta_start, args.theta_stop, args.theta_step),
                args.current_max,
                args.commutation_offset,
            )
            print(f"Created sweep results: {result}")
    finally:
        try:
            femm.closefemm()
        except Exception:
            pass


if __name__ == "__main__":
    main()
