"""Run loaded FEMM sweeps for the six-variable independent-angle design."""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path

import femm

import analyze_axis_shortedge_ccf_python as single
import generate_split_angle_double_layer_preview as geometry
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent


def refine_outer_radius(
    design: dict[str, str], inner_radius: float, inner_offset: float
) -> tuple[float, float]:
    inner = geometry.magnet_polygon(
        geometry.ROTOR_ANGLE_DEG, 1, inner_radius, inner_offset,
        geometry.INNER_ANGLE_DEG, geometry.INNER_LENGTH_MM,
        geometry.INNER_THICKNESS_MM,
    )

    def gap_at(radius: float) -> tuple[float, float]:
        offset = geometry.solve_offset(
            radius, geometry.OUTER_ANGLE_DEG,
            geometry.OUTER_LENGTH_MM, geometry.OUTER_THICKNESS_MM,
            geometry.OUTER_FLIPPED,
        )
        outer = geometry.magnet_polygon(
            geometry.ROTOR_ANGLE_DEG, 1, radius, offset,
            geometry.OUTER_ANGLE_DEG, geometry.OUTER_LENGTH_MM,
            geometry.OUTER_THICKNESS_MM, geometry.OUTER_FLIPPED,
        )
        return geometry.geom.polygon_distance(inner, outer), offset

    center = float(design["outer_center_radius_mm"])
    width = 0.25
    low, high = center - width, center + width
    for _ in range(8):
        low_gap, _ = gap_at(low)
        high_gap, _ = gap_at(high)
        if low_gap < geometry.LAYER_GAP_MM <= high_gap:
            break
        width *= 2
        low = max(inner_radius, center - width)
        high = min(base.PM_R + base.SEAL, center + width)
    else:
        raise ValueError("SAVED_LAYER_GAP_BRACKET_NOT_FOUND")
    for _ in range(35):
        middle = (low + high) / 2
        if gap_at(middle)[0] < geometry.LAYER_GAP_MM:
            low = middle
        else:
            high = middle
    radius = (low + high) / 2
    _, offset = gap_at(radius)
    return radius, offset


def configure(design: dict[str, str]) -> dict[str, float]:
    inner_thickness = float(design["inner_thickness_mm"])
    inner_length = float(design["inner_length_mm"])
    area_ratio = float(design["outer_area_ratio"])
    scale = math.sqrt(area_ratio)
    geometry.TOTAL_THICKNESS_MM = 2 * inner_thickness
    geometry.INNER_THICKNESS_MM = inner_thickness
    geometry.OUTER_THICKNESS_MM = inner_thickness * scale
    geometry.INNER_LENGTH_MM = inner_length
    geometry.OUTER_LENGTH_MM = inner_length * scale
    geometry.INNER_ANGLE_DEG = float(design["inner_angle_deg"])
    geometry.OUTER_ANGLE_DEG = float(design["outer_angle_deg"])
    geometry.OUTER_FLIPPED = False
    geometry.LAYER_GAP_MM = float(design["layer_normal_gap_mm"])

    # Refine the saved fast-search layout at full bisection accuracy.
    geometry.BISECTION_ITERATIONS = 35
    inner_radius = float(design["inner_center_radius_mm"])
    inner_offset = geometry.solve_offset(
        inner_radius,
        geometry.INNER_ANGLE_DEG,
        geometry.INNER_LENGTH_MM,
        geometry.INNER_THICKNESS_MM,
    )
    outer_radius, outer_offset = refine_outer_radius(
        design, inner_radius, inner_offset
    )
    magnets = geometry.build_magnets(
        inner_radius, outer_radius, inner_offset, outer_offset
    )
    result = geometry.metrics(magnets)
    if result["outer_bridge_min_mm"] < 1.0:
        raise ValueError("OUTER_BRIDGE_LT_1MM")
    if result["shaft_clearance_min_mm"] < 1.0:
        raise ValueError("SHAFT_CLEARANCE_LT_1MM")
    if result["layer_gap_actual_min_mm"] < geometry.LAYER_GAP_MM - 1e-5:
        raise ValueError("LAYER_GAP_ERROR")
    if result["other_magnet_gap_min_mm"] < 0.5:
        raise ValueError("OTHER_MAGNET_GAP_LT_0P5MM")
    base.draw_rotor = geometry.draw_rotor_factory(
        inner_radius, outer_radius, inner_offset, outer_offset
    )
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--design-csv",
        type=Path,
        default=ROOT / "independent_angle_sobol_64"
        / "independent_angle_sobol_6factor_64.csv",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "independent_angle_sobol_64_results",
    )
    parser.add_argument("--design-limit", type=int)
    parser.add_argument("--run-start", type=int)
    parser.add_argument("--run-stop", type=int)
    parser.add_argument("--no-aggregate", action="store_true")
    parser.add_argument("--theta-start", type=float, default=0)
    parser.add_argument("--theta-stop", type=float, default=28)
    parser.add_argument("--theta-step", type=float, default=2)
    parser.add_argument("--current-max", type=float, default=10)
    parser.add_argument("--commutation-offset", type=float, default=35)
    parser.add_argument("--show-femm", action="store_true")
    args = parser.parse_args()

    with args.design_csv.open(newline="", encoding="utf-8-sig") as stream:
        designs = list(csv.DictReader(stream))
    if args.run_start is not None:
        designs = [d for d in designs if int(d["run"]) >= args.run_start]
    if args.run_stop is not None:
        designs = [d for d in designs if int(d["run"]) <= args.run_stop]
    if args.design_limit is not None:
        designs = designs[: args.design_limit]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summaries: list[dict[str, str | float | int]] = []
    base.CORE = "M-19 Steel"
    base.define_materials = single.define_axis_shortedge_materials
    base.add_windings = single.add_axis_shortedge_windings
    femm.openfemm(0 if args.show_femm else 1)
    try:
        for index, design in enumerate(designs, 1):
            run = int(design["run"])
            print(f"Sobol {index}/{len(designs)} run={run}", flush=True)
            exact_metrics = configure(design)
            case_dir = args.output_dir / f"run_{run:03d}"
            case_dir.mkdir(exist_ok=True)
            sweep_path = single.run_sweep(
                case_dir,
                single.angles(args.theta_start, args.theta_stop, args.theta_step),
                args.current_max,
                args.commutation_offset,
            )
            with sweep_path.open(newline="", encoding="utf-8") as stream:
                sweep = [
                    {key: float(value) for key, value in row.items()}
                    for row in csv.DictReader(stream)
                ]
            summary = {
                **design,
                **{f"exact_{key}": value for key, value in exact_metrics.items()},
                "theta_start_deg": args.theta_start,
                "theta_stop_deg": args.theta_stop,
                "theta_step_deg": args.theta_step,
                "current_peak_A": args.current_max,
                "commutation_offset_deg": args.commutation_offset,
                "completed_points": len(sweep),
                **single.summarize_torque(sweep),
            }
            summaries.append(summary)
            run_summary = case_dir / "summary.csv"
            with run_summary.open("w", newline="", encoding="utf-8-sig") as stream:
                writer = csv.DictWriter(stream, fieldnames=summaries[0].keys())
                writer.writeheader()
                writer.writerow(summary)
            if not args.no_aggregate:
                partial = args.output_dir / "independent_angle_summary_partial.csv"
                with partial.open("w", newline="", encoding="utf-8-sig") as stream:
                    writer = csv.DictWriter(stream, fieldnames=summaries[0].keys())
                    writer.writeheader()
                    writer.writerows(summaries)
            print(
                f"  mean={summary['loaded_torque_mean_Nm']:.6g} Nm, "
                f"pkpk={summary['loaded_torque_pkpk_Nm']:.6g} Nm",
                flush=True,
            )
        if summaries and not args.no_aggregate:
            partial.replace(args.output_dir / "independent_angle_summary.csv")
    finally:
        femm.closefemm()


if __name__ == "__main__":
    main()
