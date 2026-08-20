"""Solve the best/worst 55–90° designs at 0 A and sample air-gap Br."""

from __future__ import annotations

import csv
import math
from pathlib import Path

import femm

import analyze_axis_shortedge_ccf_python as axis
import analyze_double_layer_ccf_python as double
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent
SOURCE = (
    ROOT / "double_layer_ccf_55to90_50_results"
    / "double_layer_ccf_summary.csv"
)
OUTPUT = ROOT / "double_layer_best_worst_no_load"
AIR_GAP_RADIUS_MM = (base.PM_R + base.SEAL + base.CORE_RI) / 2


def select_cases() -> list[tuple[str, dict[str, str]]]:
    with SOURCE.open(newline="", encoding="utf-8-sig") as stream:
        rows = list(csv.DictReader(stream))
    best = max(rows, key=lambda row: float(row["loaded_torque_mean_Nm"]))
    worst = min(rows, key=lambda row: float(row["loaded_torque_mean_Nm"]))
    return [("best", best), ("worst", worst)]


def sample_air_gap(case_dir: Path, label: str, run: int) -> Path:
    fem_path = case_dir / "v_ipm_motor_base.fem"
    femm.opendocument(str(fem_path))
    femm.mi_loadsolution()
    rows = []
    for index in range(721):
        angle_deg = 0.5 * index
        angle_rad = math.radians(angle_deg)
        x = AIR_GAP_RADIUS_MM * math.cos(angle_rad)
        y = AIR_GAP_RADIUS_MM * math.sin(angle_rad)
        bx, by = femm.mo_getb(x, y)
        rows.append(
            {
                "case": label,
                "run": run,
                "angle_deg": angle_deg,
                "Bx_T": bx,
                "By_T": by,
                "Br_T": bx * math.cos(angle_rad) + by * math.sin(angle_rad),
                "Bt_T": -bx * math.sin(angle_rad) + by * math.cos(angle_rad),
            }
        )
    output = case_dir / "airgap_flux_density_no_load.csv"
    with output.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    femm.mo_close()
    femm.mi_close()
    return output


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    cases = select_cases()
    base.CORE = "M-19 Steel"
    base.define_materials = axis.define_axis_shortedge_materials
    base.add_windings = axis.add_axis_shortedge_windings
    femm.openfemm(0)
    try:
        for label, design in cases:
            run = int(design["run"])
            case_dir = OUTPUT / f"{label}_run_{run:03d}"
            case_dir.mkdir(exist_ok=True)
            double.configure(design)
            print(f"No-load solve: {label} run {run}", flush=True)
            axis.run_sweep(
                case_dir,
                axis.angles(0, 0, 1),
                current_max=0,
                commutation_offset_deg=35,
            )
            path = sample_air_gap(case_dir, label, run)
            print(f"Created: {path}", flush=True)
    finally:
        femm.closefemm()


if __name__ == "__main__":
    main()
