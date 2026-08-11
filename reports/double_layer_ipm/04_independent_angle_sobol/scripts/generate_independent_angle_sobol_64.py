"""Build and geometry-check a 64-point, six-variable Sobol design."""

from __future__ import annotations

import csv
import math
from pathlib import Path

from scipy.stats import qmc

import generate_split_angle_double_layer_preview as geometry


ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = ROOT / "independent_angle_sobol_64"
VALID_CSV = OUTPUT_DIR / "independent_angle_sobol_6factor_64.csv"
AUDIT_CSV = OUTPUT_DIR / "independent_angle_sobol_geometry_audit.csv"
N_VALID = 64
SEED = 20260803

RANGES = {
    "inner_angle_deg": (40.0, 90.0),
    "outer_angle_deg": (50.0, 90.0),
    "outer_area_ratio": (0.50, 0.80),
    "inner_thickness_mm": (1.75, 2.75),
    "inner_length_mm": (14.5, 16.8),
    "layer_normal_gap_mm": (0.5, 2.0),
}


def configure(values: dict[str, float]) -> None:
    scale = math.sqrt(values["outer_area_ratio"])
    geometry.TOTAL_THICKNESS_MM = 2 * values["inner_thickness_mm"]
    geometry.INNER_THICKNESS_MM = values["inner_thickness_mm"]
    geometry.OUTER_THICKNESS_MM = values["inner_thickness_mm"] * scale
    geometry.INNER_LENGTH_MM = values["inner_length_mm"]
    geometry.OUTER_LENGTH_MM = values["inner_length_mm"] * scale
    geometry.INNER_ANGLE_DEG = values["inner_angle_deg"]
    geometry.OUTER_ANGLE_DEG = values["outer_angle_deg"]
    geometry.OUTER_FLIPPED = False
    geometry.LAYER_GAP_MM = values["layer_normal_gap_mm"]


def evaluate(candidate: int, values: dict[str, float]) -> dict[str, float | str]:
    configure(values)
    row: dict[str, float | str] = {
        "candidate": candidate,
        **values,
        "angle_difference_deg": (
            values["outer_angle_deg"] - values["inner_angle_deg"]
        ),
    }
    try:
        (
            _, inner_radius, outer_radius, inner_offset, outer_offset,
            _, result,
        ) = geometry.find_layout()
        row.update(
            {
                "outer_length_mm": geometry.OUTER_LENGTH_MM,
                "outer_thickness_mm": geometry.OUTER_THICKNESS_MM,
                "inner_center_radius_mm": inner_radius,
                "outer_center_radius_mm": outer_radius,
                "inner_center_offset_deg": inner_offset,
                "outer_center_offset_deg": outer_offset,
                **result,
                "geometry_status": "OK",
            }
        )
    except (RuntimeError, ValueError) as exc:
        row["geometry_status"] = f"INVALID:{exc}"
    return row


def write_csv(path: Path, rows: list[dict[str, float | str]]) -> None:
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with path.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    OUTPUT_DIR.mkdir(exist_ok=True)
    # Fast first-pass geometry search. Accepted designs are rechecked with the
    # shared module's fine defaults when their FEM files are generated.
    geometry.BISECTION_ITERATIONS = 18
    geometry.OUTER_RADIUS_SAMPLES = 40
    geometry.INNER_RADIUS_STEP_MM = 0.5
    names = list(RANGES)
    unit_points = qmc.Sobol(d=len(names), scramble=True, seed=SEED).random_base2(8)
    points = qmc.scale(
        unit_points,
        [RANGES[name][0] for name in names],
        [RANGES[name][1] for name in names],
    )
    audit: list[dict[str, float | str]] = []
    valid: list[dict[str, float | str]] = []
    for candidate, point in enumerate(points, 1):
        values = dict(zip(names, map(float, point)))
        row = evaluate(candidate, values)
        audit.append(row)
        if row["geometry_status"] == "OK":
            valid_row = {"run": len(valid) + 1, **row}
            valid.append(valid_row)
            print(f"candidate={candidate:03d} valid={len(valid):02d}/{N_VALID}", flush=True)
            if len(valid) == N_VALID:
                break
        else:
            print(f"candidate={candidate:03d} invalid", flush=True)

    write_csv(AUDIT_CSV, audit)
    if len(valid) < N_VALID:
        raise RuntimeError(f"Only {len(valid)} valid geometries from {len(audit)} attempts")
    write_csv(VALID_CSV, valid)
    print(f"Created: {VALID_CSV}")
    print(f"Audited={len(audit)}, valid={len(valid)}, invalid={len(audit) - len(valid)}")


if __name__ == "__main__":
    main()
