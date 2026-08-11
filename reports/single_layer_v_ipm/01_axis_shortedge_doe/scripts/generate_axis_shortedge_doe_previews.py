"""Generate unsolved FEM previews for a geometry-checked 4-factor DOE."""

from __future__ import annotations

import csv
import math
import random
from pathlib import Path

import femm
import generate_v_ipm_motor as base
import analyze_axis_shortedge_ccf_python as axis


ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = ROOT / "doe_axis_shortedge_previews"
FEM_DIR = OUTPUT_DIR / "fem"
DESIGN_CSV = OUTPUT_DIR / "axis_shortedge_doe_4factor_50.csv"
N_DESIGNS = 50
SEED = 20260730

RANGES = {
    "magnet_thickness_mm": (2.5, 5.5),
    "magnet_length_mm": (12.0, 16.8),
    "v_angle_deg": (35.0, 90.0),
    "tip_gap_mm": (0.5, 4.5),
}


def orientation(a, b, c) -> float:
    return (b[0] - a[0]) * (c[1] - a[1]) - (
        b[1] - a[1]
    ) * (c[0] - a[0])


def segments_intersect(a, b, c, d) -> bool:
    o1 = orientation(a, b, c)
    o2 = orientation(a, b, d)
    o3 = orientation(c, d, a)
    o4 = orientation(c, d, b)
    tolerance = 1e-12

    def on_segment(p, q, r) -> bool:
        return (
            min(p[0], r[0]) - tolerance
            <= q[0]
            <= max(p[0], r[0]) + tolerance
            and min(p[1], r[1]) - tolerance
            <= q[1]
            <= max(p[1], r[1]) + tolerance
        )

    if o1 * o2 < 0 and o3 * o4 < 0:
        return True
    return (
        abs(o1) <= tolerance and on_segment(a, c, b)
        or abs(o2) <= tolerance and on_segment(a, d, b)
        or abs(o3) <= tolerance and on_segment(c, a, d)
        or abs(o4) <= tolerance and on_segment(c, b, d)
    )


def point_segment_distance(p, a, b) -> float:
    dx, dy = b[0] - a[0], b[1] - a[1]
    denominator = dx * dx + dy * dy
    if denominator == 0:
        return math.dist(p, a)
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / denominator
    t = min(1.0, max(0.0, t))
    projection = (a[0] + t * dx, a[1] + t * dy)
    return math.dist(p, projection)


def polygon_distance(poly_a, poly_b) -> float:
    edges_a = list(zip(poly_a, poly_a[1:] + poly_a[:1]))
    edges_b = list(zip(poly_b, poly_b[1:] + poly_b[:1]))
    if any(
        segments_intersect(a, b, c, d)
        for a, b in edges_a
        for c, d in edges_b
    ):
        return 0.0
    distances = []
    for point in poly_a:
        distances.extend(
            point_segment_distance(point, c, d) for c, d in edges_b
        )
    for point in poly_b:
        distances.extend(
            point_segment_distance(point, a, b) for a, b in edges_a
        )
    return min(distances)


def pole_pair(
    offset_deg: float,
    length_mm: float,
    thickness_mm: float,
    v_angle_deg: float,
    pole_axis_deg: float = -10,
):
    positive = axis.polygon(
        pole_axis_deg + offset_deg,
        pole_axis_deg + v_angle_deg,
        pole_axis_deg,
        length_mm,
        thickness_mm,
        1,
    )
    negative = axis.polygon(
        pole_axis_deg - offset_deg,
        pole_axis_deg - v_angle_deg,
        pole_axis_deg,
        length_mm,
        thickness_mm,
        -1,
    )
    return positive, negative


def solve_offset_for_actual_gap(
    target_gap_mm: float,
    length_mm: float,
    thickness_mm: float,
    v_angle_deg: float,
) -> float:
    def gap(offset_deg: float) -> float:
        return polygon_distance(
            *pole_pair(
                offset_deg, length_mm, thickness_mm, v_angle_deg
            )
        )

    low, high = 0.0, 60.0
    if gap(high) < target_gap_mm:
        raise ValueError("Target gap cannot be reached inside 60 degrees")
    for _ in range(60):
        middle = (low + high) / 2
        if gap(middle) < target_gap_mm:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def make_lhs(n: int, dimensions: int, seed: int) -> list[list[float]]:
    rng = random.Random(seed)
    best = None
    best_min_distance = -1.0
    for _ in range(600):
        columns = []
        for _dimension in range(dimensions):
            values = [(index + rng.random()) / n for index in range(n)]
            rng.shuffle(values)
            columns.append(values)
        candidate = [
            [columns[dimension][row] for dimension in range(dimensions)]
            for row in range(n)
        ]
        minimum = min(
            math.dist(candidate[i], candidate[j])
            for i in range(n)
            for j in range(i)
        )
        if minimum > best_min_distance:
            best_min_distance = minimum
            best = candidate
    assert best is not None
    return best


def scale(value: float, bounds: tuple[float, float]) -> float:
    return bounds[0] + value * (bounds[1] - bounds[0])


def normalized_vector(row: dict[str, float]) -> tuple[float, ...]:
    return tuple(
        (row[name] - bounds[0]) / (bounds[1] - bounds[0])
        for name, bounds in RANGES.items()
    )


def all_magnets(row: dict[str, float]):
    polygons = []
    for pole_axis in (-10, 80, 170, 260):
        for side in (1, -1):
            polygons.append(
                axis.polygon(
                    pole_axis + side * row["magnet_center_offset_deg"],
                    pole_axis + side * row["v_angle_deg"],
                    pole_axis,
                    row["magnet_length_mm"],
                    row["magnet_thickness_mm"],
                    side,
                )
            )
    return polygons


def geometry_metrics(row: dict[str, float]) -> dict[str, float]:
    polygons = all_magnets(row)
    vertices = [point for polygon in polygons for point in polygon]
    outer_bridge = base.PM_R + base.SEAL - max(
        math.hypot(*point) for point in vertices
    )
    shaft_clearance = min(
        point_segment_distance(
            (0.0, 0.0), polygon[index], polygon[(index + 1) % 4]
        )
        for polygon in polygons
        for index in range(4)
    ) - base.SHAFT_R
    same_pole_gap = polygon_distance(polygons[0], polygons[1])
    adjacent_pole_gap = min(
        polygon_distance(polygons[i], polygons[j])
        for i in range(8)
        for j in range(i)
        if i // 2 != j // 2
    )
    return {
        "actual_tip_gap_mm": same_pole_gap,
        "outer_bridge_min_mm": outer_bridge,
        "shaft_clearance_min_mm": shaft_clearance,
        "adjacent_pole_gap_min_mm": adjacent_pole_gap,
    }


def evaluate_row(run: int, values: dict[str, float]) -> dict[str, float]:
    row = {"run": run, **values}
    row["magnet_center_offset_deg"] = solve_offset_for_actual_gap(
        row["tip_gap_mm"],
        row["magnet_length_mm"],
        row["magnet_thickness_mm"],
        row["v_angle_deg"],
    )
    row.update(geometry_metrics(row))
    issues = []
    if row["adjacent_pole_gap_min_mm"] <= 1e-9:
        issues.append("INVALID_ADJACENT_MAGNET_OVERLAP")
    if row["outer_bridge_min_mm"] <= 0:
        issues.append("INVALID_OUTSIDE_ROTOR")
    elif row["outer_bridge_min_mm"] < 1.0:
        issues.append("WARNING_OUTER_BRIDGE_LT_1MM")
    if row["shaft_clearance_min_mm"] <= 0:
        issues.append("INVALID_SHAFT_OVERLAP")
    row["geometry_status"] = "|".join(issues) if issues else "OK"
    return row


def save_preview(row: dict[str, float], filename: Path) -> None:
    base.draw_rotor = axis.make_draw_rotor(
        row["magnet_length_mm"],
        row["magnet_thickness_mm"],
        row["v_angle_deg"],
        row["tip_gap_mm"],
    )
    # Override the old nominal-gap conversion with the solved actual-gap offset.
    solved_offset = row["magnet_center_offset_deg"]

    def draw_with_solved_offset(rotor_mech_angle_deg: float = 0) -> None:
        original_solver = axis.center_offset_deg
        axis.center_offset_deg = lambda *_args: solved_offset
        try:
            axis.make_draw_rotor(
                row["magnet_length_mm"],
                row["magnet_thickness_mm"],
                row["v_angle_deg"],
                row["tip_gap_mm"],
            )(rotor_mech_angle_deg)
        finally:
            axis.center_offset_deg = original_solver

    base.draw_rotor = draw_with_solved_offset
    femm.newdocument(0)
    femm.mi_probdef(0, "millimeters", "planar", 1e-8, base.DEPTH, 30, 0)
    axis.define_axis_shortedge_materials()
    base.draw_rotor(-10)
    base.draw_stator()
    axis.add_axis_shortedge_windings()
    femm.mi_makeABC(7, base.PM_R * 20, 0, 0, 0)
    femm.mi_saveas(str(filename))
    femm.mi_close()


def main() -> None:
    names = list(RANGES)
    samples = make_lhs(N_DESIGNS, len(names), SEED)
    rows = []
    for index, sample in enumerate(samples, start=1):
        row = evaluate_row(
            index,
            {
                name: scale(sample[column], RANGES[name])
                for column, name in enumerate(names)
            },
        )
        rows.append(row)

    valid_rows = [row for row in rows if row["geometry_status"] == "OK"]
    replacement_runs = [
        row["run"] for row in rows if row["geometry_status"] != "OK"
    ]
    rng = random.Random(SEED + 1)
    for run in replacement_runs:
        candidates = []
        while len(candidates) < 300:
            values = {
                name: rng.uniform(*bounds) for name, bounds in RANGES.items()
            }
            candidate = evaluate_row(run, values)
            if candidate["geometry_status"] == "OK":
                candidates.append(candidate)
        existing = [normalized_vector(row) for row in valid_rows]
        replacement = max(
            candidates,
            key=lambda candidate: min(
                math.dist(normalized_vector(candidate), point)
                for point in existing
            ),
        )
        valid_rows.append(replacement)
    rows = sorted(valid_rows, key=lambda row: row["run"])

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    FEM_DIR.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0])
    with DESIGN_CSV.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    base.CORE = "M-19 Steel"
    base.define_materials = axis.define_axis_shortedge_materials
    base.add_windings = axis.add_axis_shortedge_windings
    try:
        femm.openfemm(1)
        for index, row in enumerate(rows, start=1):
            filename = FEM_DIR / f"run_{index:03d}.fem"
            save_preview(row, filename)
            print(f"{index:02d}/{len(rows)} {filename.name}")
    finally:
        try:
            femm.closefemm()
        except Exception:
            pass

    print(DESIGN_CSV)


if __name__ == "__main__":
    main()
