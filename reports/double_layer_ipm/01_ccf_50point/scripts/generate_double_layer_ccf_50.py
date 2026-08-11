"""Generate a geometry-checked 50-point double-layer CCF design."""

from __future__ import annotations

import csv
import math
from pathlib import Path

import femm
import numpy as np
from scipy.stats import qmc

import analyze_axis_shortedge_ccf_python as axis
import generate_axis_shortedge_doe_previews as geom
import generate_double_layer_candidate625_preview as dl
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = ROOT / "double_layer_ccf_50_previews"
FEM_DIR = OUTPUT_DIR / "fem"
DESIGN_CSV = OUTPUT_DIR / "double_layer_ccf_4factor_50.csv"
N_DESIGNS = 50
SEED = 20260801
FIXED_TIP_GAP_MM = dl.TIP_GAP_MM

RANGES = {
    "total_thickness_mm": (3.5, 5.5),
    "inner_length_mm": (14.5, 16.8),
    "v_angle_deg": (70.0, 90.0),
    "layer_normal_gap_mm": (0.5, 2.0),
}


def configure(values: dict[str, float], offset_deg: float) -> None:
    dl.TOTAL_THICKNESS_MM = values["total_thickness_mm"]
    dl.OUTER_LENGTH_MM = values["inner_length_mm"]
    dl.V_ANGLE_DEG = values["v_angle_deg"]
    dl.LAYER_NORMAL_GAP_MM = values["layer_normal_gap_mm"]
    dl.CENTER_OFFSET_DEG = offset_deg


def same_pole_opposite_side_gap() -> float:
    magnets = dl.layer_polygons()
    gaps = []
    for pole in range(4):
        positive = [
            m["points"] for m in magnets
            if m["pole"] == pole and m["side"] == 1
        ]
        negative = [
            m["points"] for m in magnets
            if m["pole"] == pole and m["side"] == -1
        ]
        gaps.extend(
            geom.polygon_distance(a, b) for a in positive for b in negative
        )
    return min(gaps)


def solve_offset(values: dict[str, float]) -> float:
    low, high = 0.0, 60.0
    configure(values, high)
    if same_pole_opposite_side_gap() < FIXED_TIP_GAP_MM:
        raise ValueError("Fixed TIPGAP cannot be reached")
    for _ in range(60):
        middle = (low + high) / 2
        configure(values, middle)
        if same_pole_opposite_side_gap() < FIXED_TIP_GAP_MM:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def evaluate(run: int, values: dict[str, float]) -> dict[str, float | str]:
    offset = solve_offset(values)
    configure(values, offset)
    metrics = dl.calculate_metrics(dl.layer_polygons())
    issues = []
    if metrics["outer_bridge_min_mm"] < 1.0:
        issues.append("OUTER_BRIDGE_LT_1MM")
    if metrics["shaft_clearance_min_mm"] <= 0:
        issues.append("SHAFT_OVERLAP")
    if metrics["layer_gap_actual_min_mm"] < values["layer_normal_gap_mm"] - 1e-6:
        issues.append("LAYER_GAP_ERROR")
    if metrics["other_magnet_gap_min_mm"] < 0.5:
        issues.append("OTHER_MAGNET_GAP_LT_0P5MM")
    return {
        "run": run,
        **values,
        "tip_gap_mm": FIXED_TIP_GAP_MM,
        "magnet_center_offset_deg": offset,
        "outer_length_mm": values["inner_length_mm"] * dl.OUTER_LENGTH_SCALE,
        "inner_thickness_mm": values["total_thickness_mm"] / 2,
        "outer_thickness_mm": (
            values["total_thickness_mm"] / 2 * dl.OUTER_THICKNESS_SCALE
        ),
        "outer_length_scale": dl.OUTER_LENGTH_SCALE,
        "outer_thickness_scale": dl.OUTER_THICKNESS_SCALE,
        "pair_radial_shift_mm": dl.PAIR_RADIAL_SHIFT_MM,
        **metrics,
        "geometry_status": "|".join(issues) if issues else "OK",
    }


def save_preview(row: dict[str, float | str], filename: Path) -> None:
    values = {name: float(row[name]) for name in RANGES}
    configure(values, float(row["magnet_center_offset_deg"]))
    base.draw_rotor = dl.draw_rotor
    femm.newdocument(0)
    femm.mi_probdef(0, "millimeters", "planar", 1e-8, base.DEPTH, 30, 0)
    axis.define_axis_shortedge_materials()
    dl.draw_rotor()
    base.draw_stator()
    axis.add_axis_shortedge_windings()
    femm.mi_makeABC(7, base.PM_R * 20, 0, 0, 0)
    femm.mi_saveas(str(filename))
    femm.mi_close()


def main() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)
    FEM_DIR.mkdir(exist_ok=True)
    names = list(RANGES)
    sampler = qmc.LatinHypercube(
        d=len(names), seed=SEED, optimization="random-cd"
    )
    pool = qmc.scale(
        sampler.random(4000),
        [RANGES[name][0] for name in names],
        [RANGES[name][1] for name in names],
    )
    valid = []
    for values_array in pool:
        values = dict(zip(names, map(float, values_array)))
        row = evaluate(len(valid) + 1, values)
        if row["geometry_status"] == "OK":
            valid.append(row)
            if len(valid) == N_DESIGNS:
                break
    if len(valid) < N_DESIGNS:
        raise RuntimeError(f"Only {len(valid)} valid designs found")

    with DESIGN_CSV.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=valid[0].keys())
        writer.writeheader()
        writer.writerows(valid)

    femm.openfemm(1)
    try:
        for row in valid:
            save_preview(
                row, FEM_DIR / f"run_{int(row['run']):03d}.fem"
            )
    finally:
        femm.closefemm()

    print(f"Created: {DESIGN_CSV}")
    print(f"Valid designs: {len(valid)}")
    print(
        "Minimum clearances:",
        min(float(r["outer_bridge_min_mm"]) for r in valid),
        min(float(r["other_magnet_gap_min_mm"]) for r in valid),
    )


if __name__ == "__main__":
    main()
