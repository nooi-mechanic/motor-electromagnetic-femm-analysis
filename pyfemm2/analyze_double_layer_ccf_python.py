"""Run loaded FEMM sweeps for the 50-point double-layer CCF design."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import femm

import analyze_axis_shortedge_ccf_python as single
import generate_double_layer_candidate625_preview as dl
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent


def configure(design: dict[str, str]) -> None:
    dl.TOTAL_THICKNESS_MM = float(design["total_thickness_mm"])
    dl.OUTER_LENGTH_MM = float(design["inner_length_mm"])
    dl.V_ANGLE_DEG = float(design["v_angle_deg"])
    dl.LAYER_NORMAL_GAP_MM = float(design["layer_normal_gap_mm"])
    dl.CENTER_OFFSET_DEG = float(design["magnet_center_offset_deg"])
    base.draw_rotor = dl.draw_rotor


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--design-csv",
        type=Path,
        default=ROOT / "double_layer_ccf_50_previews"
        / "double_layer_ccf_4factor_50.csv",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=ROOT / "double_layer_ccf_50_results",
    )
    parser.add_argument("--design-limit", type=int)
    parser.add_argument("--theta-start", type=float, default=0)
    parser.add_argument("--theta-stop", type=float, default=28)
    parser.add_argument("--theta-step", type=float, default=2)
    parser.add_argument("--current-max", type=float, default=10)
    parser.add_argument("--commutation-offset", type=float, default=35)
    parser.add_argument(
        "--show-femm",
        action="store_true",
        help="Show the FEMM application window while solving.",
    )
    args = parser.parse_args()

    with args.design_csv.open(newline="", encoding="utf-8-sig") as stream:
        designs = list(csv.DictReader(stream))
    if args.design_limit is not None:
        designs = designs[: args.design_limit]
    args.output_dir.mkdir(parents=True, exist_ok=True)
    summaries = []

    base.CORE = "M-19 Steel"
    base.define_materials = single.define_axis_shortedge_materials
    base.add_windings = single.add_axis_shortedge_windings
    femm.openfemm(0 if args.show_femm else 1)
    try:
        for index, design in enumerate(designs, 1):
            configure(design)
            run = int(design["run"])
            case_dir = args.output_dir / f"run_{run:03d}"
            case_dir.mkdir(exist_ok=True)
            print(f"CCF {index}/{len(designs)} run={run}", flush=True)
            sweep_path = single.run_sweep(
                case_dir,
                single.angles(
                    args.theta_start, args.theta_stop, args.theta_step
                ),
                args.current_max,
                args.commutation_offset,
            )
            with sweep_path.open(newline="", encoding="utf-8") as stream:
                sweep = [
                    {key: float(value) for key, value in row.items()}
                    for row in csv.DictReader(stream)
                ]
            summary = {
                **{key: value for key, value in design.items()},
                "theta_start_deg": args.theta_start,
                "theta_stop_deg": args.theta_stop,
                "theta_step_deg": args.theta_step,
                "current_peak_A": args.current_max,
                "commutation_offset_deg": args.commutation_offset,
                "completed_points": len(sweep),
                **single.summarize_torque(sweep),
            }
            summaries.append(summary)
            partial = (
                args.output_dir / "double_layer_ccf_summary_partial.csv"
            )
            with partial.open("w", newline="", encoding="utf-8") as stream:
                writer = csv.DictWriter(
                    stream, fieldnames=summaries[0].keys()
                )
                writer.writeheader()
                writer.writerows(summaries)
            print(
                f"  mean={summary['loaded_torque_mean_Nm']:.6g} Nm, "
                f"pkpk={summary['loaded_torque_pkpk_Nm']:.6g} Nm",
                flush=True,
            )
        partial.replace(
            args.output_dir / "double_layer_ccf_summary.csv"
        )
    finally:
        femm.closefemm()


if __name__ == "__main__":
    main()
