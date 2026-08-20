"""Create one split-angle double-layer IPM FEM preview."""

from __future__ import annotations

import csv
import math
from pathlib import Path

import femm

import analyze_axis_shortedge_ccf_python as axis
import generate_axis_shortedge_doe_previews as geom
import generate_double_layer_candidate625_preview as common
import generate_v_ipm_motor as base


ROOT = Path(__file__).resolve().parent
OUTPUT_DIR = ROOT / "split_angle_double_layer_preview"
FEM_FILE = OUTPUT_DIR / "split_angle_flipped_outer_preview.fem"
METRICS_FILE = OUTPUT_DIR / "split_angle_flipped_outer_metrics.csv"

TOTAL_THICKNESS_MM = 2.5
INNER_LENGTH_MM = 13.0
INNER_ANGLE_DEG = 32.5
OUTER_ANGLE_DEG = 57.5
OUTER_FLIPPED = True
OUTER_LENGTH_SCALE = 0.8
OUTER_THICKNESS_SCALE = 0.8
TIP_GAP_MM = 0.6075381037704741
LAYER_GAP_MM = 1.2
ROTOR_ANGLE_DEG = -10.0

INNER_THICKNESS_MM = TOTAL_THICKNESS_MM / 2
OUTER_THICKNESS_MM = INNER_THICKNESS_MM * OUTER_THICKNESS_SCALE
OUTER_LENGTH_MM = INNER_LENGTH_MM * OUTER_LENGTH_SCALE


def magnet_polygon(
    pole_axis: float,
    side: int,
    radius: float,
    offset_deg: float,
    angle_deg: float,
    length_mm: float,
    thickness_mm: float,
    flipped: bool = False,
):
    center = base.polar(
        radius, math.radians(pole_axis + side * offset_deg)
    )
    return common.polygon_at_center(
        center,
        pole_axis + (-side if flipped else side) * angle_deg,
        pole_axis,
        length_mm,
        thickness_mm,
        side,
    )


def solve_offset(
    radius: float,
    angle_deg: float,
    length_mm: float,
    thickness_mm: float,
    flipped: bool = False,
) -> float:
    def gap(offset):
        return geom.polygon_distance(
            magnet_polygon(
                ROTOR_ANGLE_DEG, 1, radius, offset,
                angle_deg, length_mm, thickness_mm, flipped,
            ),
            magnet_polygon(
                ROTOR_ANGLE_DEG, -1, radius, offset,
                angle_deg, length_mm, thickness_mm, flipped,
            ),
        )

    low, high = 0.0, 70.0
    if gap(high) < TIP_GAP_MM:
        raise ValueError("TIPGAP cannot be reached")
    for _ in range(35):
        middle = (low + high) / 2
        if gap(middle) < TIP_GAP_MM:
            low = middle
        else:
            high = middle
    return (low + high) / 2


def solve_outer_radius(inner_radius: float, inner_offset: float):
    inner = magnet_polygon(
        ROTOR_ANGLE_DEG, 1, inner_radius, inner_offset,
        INNER_ANGLE_DEG, INNER_LENGTH_MM, INNER_THICKNESS_MM,
    )

    def layer_gap(outer_radius):
        outer_offset = solve_offset(
            outer_radius, OUTER_ANGLE_DEG,
            OUTER_LENGTH_MM, OUTER_THICKNESS_MM,
            OUTER_FLIPPED,
        )
        outer = magnet_polygon(
            ROTOR_ANGLE_DEG, 1, outer_radius, outer_offset,
            OUTER_ANGLE_DEG, OUTER_LENGTH_MM, OUTER_THICKNESS_MM,
            OUTER_FLIPPED,
        )
        return geom.polygon_distance(inner, outer), outer_offset

    low = inner_radius
    high = base.PM_R + base.SEAL
    if layer_gap(high)[0] < LAYER_GAP_MM:
        raise ValueError("Layer gap cannot be reached")

    # Find the first non-overlapping branch, then refine the target gap.
    samples = [
        low + (high - low) * index / 200 for index in range(201)
    ]
    bracket = None
    previous_r = samples[0]
    previous_gap = layer_gap(previous_r)[0]
    for radius in samples[1:]:
        current_gap = layer_gap(radius)[0]
        if previous_gap < LAYER_GAP_MM <= current_gap:
            bracket = (previous_r, radius)
            break
        previous_r, previous_gap = radius, current_gap
    if bracket is None:
        raise ValueError("No monotonic layer-gap bracket found")

    low, high = bracket
    for _ in range(35):
        middle = (low + high) / 2
        if layer_gap(middle)[0] < LAYER_GAP_MM:
            low = middle
        else:
            high = middle
    radius = (low + high) / 2
    gap, offset = layer_gap(radius)
    return radius, offset, gap


def build_magnets(
    inner_radius: float,
    outer_radius: float,
    inner_offset: float,
    outer_offset: float,
    rotor_angle: float = ROTOR_ANGLE_DEG,
):
    magnets = []
    for pole_index, nominal_axis in enumerate((0, 90, 180, 270)):
        pole_axis = nominal_axis + rotor_angle
        magnetization = (
            pole_axis if pole_index % 2 == 0 else pole_axis + 180
        ) % 360
        for side in (1, -1):
            for layer, radius, offset, angle, length, thickness in (
                (
                    "inner", inner_radius, inner_offset,
                    INNER_ANGLE_DEG, INNER_LENGTH_MM,
                    INNER_THICKNESS_MM,
                ),
                (
                    "outer", outer_radius, outer_offset,
                    OUTER_ANGLE_DEG, OUTER_LENGTH_MM,
                    OUTER_THICKNESS_MM,
                ),
            ):
                magnets.append(
                    {
                        "pole": pole_index,
                        "side": side,
                        "layer": layer,
                        "magnetization": magnetization,
                        "points": magnet_polygon(
                            pole_axis, side, radius, offset,
                            angle, length, thickness,
                            layer == "outer" and OUTER_FLIPPED,
                        ),
                    }
                )
    return magnets


def metrics(magnets):
    polygons = [item["points"] for item in magnets]
    vertices = [point for polygon in polygons for point in polygon]
    outer_bridge = base.PM_R + base.SEAL - max(
        math.hypot(*point) for point in vertices
    )
    shaft_clearance = min(
        geom.point_segment_distance(
            (0, 0), polygon[i], polygon[(i + 1) % 4]
        )
        for polygon in polygons for i in range(4)
    ) - base.SHAFT_R
    layer_gaps = []
    other_gaps = []
    for i in range(len(magnets)):
        for j in range(i):
            gap = geom.polygon_distance(polygons[i], polygons[j])
            same_wing = (
                magnets[i]["pole"] == magnets[j]["pole"]
                and magnets[i]["side"] == magnets[j]["side"]
            )
            if same_wing:
                layer_gaps.append(gap)
            else:
                other_gaps.append(gap)
    return {
        "outer_bridge_min_mm": outer_bridge,
        "shaft_clearance_min_mm": shaft_clearance,
        "layer_gap_actual_min_mm": min(layer_gaps),
        "other_magnet_gap_min_mm": min(other_gaps),
    }


def find_layout():
    valid = []
    for inner_radius in [
        16.0 + 0.1 * index for index in range(51)
    ]:
        try:
            inner_offset = solve_offset(
                inner_radius, INNER_ANGLE_DEG,
                INNER_LENGTH_MM, INNER_THICKNESS_MM,
            )
            outer_radius, outer_offset, _ = solve_outer_radius(
                inner_radius, inner_offset
            )
            magnets = build_magnets(
                inner_radius, outer_radius, inner_offset, outer_offset
            )
            result = metrics(magnets)
            if (
                result["outer_bridge_min_mm"] >= 1.0
                and result["shaft_clearance_min_mm"] >= 1.0
                and result["layer_gap_actual_min_mm"] >= LAYER_GAP_MM - 1e-5
                and result["other_magnet_gap_min_mm"] >= 0.5
            ):
                score = min(
                    result["outer_bridge_min_mm"],
                    result["shaft_clearance_min_mm"],
                )
                valid.append(
                    (
                        score, inner_radius, outer_radius,
                        inner_offset, outer_offset, magnets, result,
                    )
                )
        except ValueError:
            continue
    if not valid:
        raise RuntimeError("No valid midpoint split-angle layout found")
    return max(valid, key=lambda item: item[0])


def draw_rotor_factory(
    inner_radius, outer_radius, inner_offset, outer_offset
):
    def draw_rotor(rotor_mech_angle_deg=ROTOR_ANGLE_DEG):
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
        for magnet in build_magnets(
            inner_radius, outer_radius, inner_offset, outer_offset,
            rotor_mech_angle_deg,
        ):
            points = magnet["points"]
            for start, end in zip(points, points[1:] + points[:1]):
                femm.mi_drawline(*start, *end)
            cx = sum(point[0] for point in points) / 4
            cy = sum(point[1] for point in points) / 4
            base.add_block(
                cx, cy, base.PM,
                magnetization_deg=magnet["magnetization"], group=1,
            )
        base.add_block(base.SHAFT_R + 0.1, 0, base.CORE, group=1)
        base.add_block(0, 0, "Air", group=1)
        femm.mi_selectcircle(0, 0, rotor_outer_r + 1, 4)
        femm.mi_setgroup(1)
        femm.mi_clearselected()

    return draw_rotor


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    (
        _, inner_radius, outer_radius,
        inner_offset, outer_offset, magnets, result,
    ) = find_layout()
    draw_rotor = draw_rotor_factory(
        inner_radius, outer_radius, inner_offset, outer_offset
    )
    base.CORE = "M-19 Steel"
    base.draw_rotor = draw_rotor
    femm.openfemm(0)
    try:
        femm.newdocument(0)
        femm.mi_probdef(
            0, "millimeters", "planar", 1e-8, base.DEPTH, 30, 0
        )
        axis.define_axis_shortedge_materials()
        draw_rotor()
        base.draw_stator()
        axis.add_axis_shortedge_windings()
        femm.mi_makeABC(7, base.PM_R * 20, 0, 0, 0)
        femm.mi_saveas(str(FEM_FILE))
        femm.mi_close()
    finally:
        femm.closefemm()

    row = {
        "total_thickness_mm": TOTAL_THICKNESS_MM,
        "inner_thickness_mm": INNER_THICKNESS_MM,
        "outer_thickness_mm": OUTER_THICKNESS_MM,
        "inner_length_mm": INNER_LENGTH_MM,
        "outer_length_mm": OUTER_LENGTH_MM,
        "inner_angle_deg": INNER_ANGLE_DEG,
        "outer_angle_deg": OUTER_ANGLE_DEG,
        "outer_flipped": OUTER_FLIPPED,
        "tip_gap_mm": TIP_GAP_MM,
        "layer_gap_target_mm": LAYER_GAP_MM,
        "inner_center_radius_mm": inner_radius,
        "outer_center_radius_mm": outer_radius,
        "inner_center_offset_deg": inner_offset,
        "outer_center_offset_deg": outer_offset,
        "magnet_area_ratio_vs_TL": 0.82,
        **result,
    }
    with METRICS_FILE.open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=row)
        writer.writeheader()
        writer.writerow(row)
    print(f"Created: {FEM_FILE}")
    for key, value in row.items():
        print(f"{key}={value}")


if __name__ == "__main__":
    main()
