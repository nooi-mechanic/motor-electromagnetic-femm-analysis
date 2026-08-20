"""Run one loaded FEMM sweep for the flipped-outer split-angle rotor."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import femm

import analyze_axis_shortedge_ccf_python as axis
import generate_split_angle_double_layer_preview as split
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "split_angle_flipped_outer_10a_results",
    )
    parser.add_argument("--theta-start", type=float, default=0)
    parser.add_argument("--theta-stop", type=float, default=30)
    parser.add_argument("--theta-step", type=float, default=1)
    parser.add_argument("--current-max", type=float, default=10)
    parser.add_argument("--commutation-offset", type=float, default=35)
    parser.add_argument("--show-femm", action="store_true")
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    (
        _,
        inner_radius,
        outer_radius,
        inner_offset,
        outer_offset,
        _,
        geometry_metrics,
    ) = split.find_layout()

    base.CORE = "M-19 Steel"
    base.define_materials = axis.define_axis_shortedge_materials
    base.add_windings = axis.add_axis_shortedge_windings
    base.draw_rotor = split.draw_rotor_factory(
        inner_radius, outer_radius, inner_offset, outer_offset
    )

    femm.openfemm(0 if args.show_femm else 1)
    try:
        sweep_path = axis.run_sweep(
            args.output_dir,
            axis.angles(args.theta_start, args.theta_stop, args.theta_step),
            args.current_max,
            args.commutation_offset,
            rotor_initial_angle_deg=split.ROTOR_ANGLE_DEG,
        )
    finally:
        femm.closefemm()

    with sweep_path.open(newline="", encoding="utf-8") as stream:
        rows = [
            {key: float(value) for key, value in row.items()}
            for row in csv.DictReader(stream)
        ]

    summary = {
        "case": "split_angle_flipped_outer",
        "inner_angle_deg": split.INNER_ANGLE_DEG,
        "outer_angle_deg": split.OUTER_ANGLE_DEG,
        "outer_flipped": split.OUTER_FLIPPED,
        "inner_length_mm": split.INNER_LENGTH_MM,
        "outer_length_mm": split.OUTER_LENGTH_MM,
        "inner_thickness_mm": split.INNER_THICKNESS_MM,
        "outer_thickness_mm": split.OUTER_THICKNESS_MM,
        "layer_gap_mm": split.LAYER_GAP_MM,
        "theta_start_deg": args.theta_start,
        "theta_stop_deg": args.theta_stop,
        "theta_step_deg": args.theta_step,
        "current_peak_A": args.current_max,
        "commutation_offset_deg": args.commutation_offset,
        "completed_points": len(rows),
        **geometry_metrics,
        **axis.summarize_torque(rows),
    }
    summary_path = args.output_dir / "split_angle_flipped_outer_summary.csv"
    with summary_path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=summary.keys())
        writer.writeheader()
        writer.writerow(summary)

    print(f"Sweep: {sweep_path}")
    print(f"Summary: {summary_path}")
    print(
        f"Mean torque={summary['loaded_torque_mean_Nm']:.6f} Nm, "
        f"pk-pk={summary['loaded_torque_pkpk_Nm']:.6f} Nm, "
        f"ripple={summary['loaded_torque_ripple_pct']:.3f}%"
    )


if __name__ == "__main__":
    main()
