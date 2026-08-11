"""Prepare and optionally run a matched-pair FEMM ripple-physics experiment.

The default action is preparation only and never opens FEMM.  Use the explicit
``--run-femm`` flag later, after other FEMM jobs have finished.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "independent_angle_sobol_64_results" / "independent_angle_summary.csv"
OUTPUT = ROOT / "inner_angle_ripple_physics_experiment"
PLAN_CSV = OUTPUT / "matched_pair_plan.csv"
CONFIG_JSON = OUTPUT / "experiment_config.json"
MU0 = 4e-7 * math.pi

VARIABLES = [
    "inner_angle_deg", "outer_angle_deg", "outer_area_ratio",
    "inner_thickness_mm", "inner_length_mm", "layer_normal_gap_mm",
]
NUISANCE = [
    "outer_angle_deg", "outer_area_ratio", "inner_thickness_mm",
    "inner_length_mm", "layer_normal_gap_mm",
]


def add_magnet_area(frame: pd.DataFrame) -> pd.DataFrame:
    frame = frame.copy()
    inner = (
        frame.inner_length_mm * frame.inner_thickness_mm
        / np.abs(np.sin(np.deg2rad(frame.inner_angle_deg)))
    )
    outer = (
        frame.outer_length_mm * frame.outer_thickness_mm
        / np.abs(np.sin(np.deg2rad(frame.outer_angle_deg)))
    )
    frame["total_magnet_area_mm2"] = 8 * (inner + outer)
    return frame


def select_matched_pair(frame: pd.DataFrame) -> tuple[pd.Series, pd.Series, pd.DataFrame]:
    """Find a pair isolating inner-angle/ripple change as closely as DOE allows."""
    valid = frame.loc[
        (frame.geometry_status == "OK") & (frame.completed_points == 15)
    ].copy()
    valid = add_magnet_area(valid).reset_index(drop=True)
    scale = valid[NUISANCE].std(ddof=0).replace(0, 1)
    rows = []
    for i in range(len(valid)):
        for j in range(i + 1, len(valid)):
            a, b = valid.iloc[i], valid.iloc[j]
            angle_delta = abs(a.inner_angle_deg - b.inner_angle_deg)
            ripple_delta = abs(a.loaded_torque_ripple_pct - b.loaded_torque_ripple_pct)
            torque_rel = abs(a.loaded_torque_mean_Nm - b.loaded_torque_mean_Nm) / (
                0.5 * (abs(a.loaded_torque_mean_Nm) + abs(b.loaded_torque_mean_Nm))
            )
            area_rel = abs(a.total_magnet_area_mm2 - b.total_magnet_area_mm2) / (
                0.5 * (a.total_magnet_area_mm2 + b.total_magnet_area_mm2)
            )
            nuisance_distance = float(np.sqrt(np.mean(((a[NUISANCE] - b[NUISANCE]) / scale) ** 2)))
            eligible = angle_delta >= 15 and ripple_delta >= 5 and torque_rel <= .10 and area_rel <= .15
            score = (
                angle_delta / 50 + ripple_delta / valid.loaded_torque_ripple_pct.std(ddof=0)
                - 4.0 * torque_rel - 3.0 * area_rel - 0.8 * nuisance_distance
            )
            rows.append({
                "i": i, "j": j, "run_a": int(a.run), "run_b": int(b.run),
                "inner_angle_delta_deg": angle_delta,
                "ripple_delta_pctpoint": ripple_delta,
                "mean_torque_relative_delta": torque_rel,
                "magnet_area_relative_delta": area_rel,
                "nuisance_normalized_distance": nuisance_distance,
                "eligible": eligible, "selection_score": score,
            })
    candidates = pd.DataFrame(rows).sort_values("selection_score", ascending=False)
    pool = candidates.loc[candidates.eligible]
    chosen = (pool if len(pool) else candidates).iloc[0]
    a, b = valid.iloc[int(chosen.i)].copy(), valid.iloc[int(chosen.j)].copy()
    # Name by observed ripple, not by torque.
    low, high = (a, b) if a.loaded_torque_ripple_pct <= b.loaded_torque_ripple_pct else (b, a)
    return low, high, candidates


def configure_geometry_module(row: pd.Series):
    import generate_split_angle_double_layer_preview as geom

    geom.INNER_THICKNESS_MM = float(row.inner_thickness_mm)
    geom.OUTER_THICKNESS_MM = float(row.outer_thickness_mm)
    geom.INNER_LENGTH_MM = float(row.inner_length_mm)
    geom.OUTER_LENGTH_MM = float(row.outer_length_mm)
    geom.INNER_ANGLE_DEG = float(row.inner_angle_deg)
    geom.OUTER_ANGLE_DEG = float(row.outer_angle_deg)
    geom.OUTER_FLIPPED = False
    geom.LAYER_GAP_MM = float(row.layer_normal_gap_mm)
    return geom


def magnets_for(row: pd.Series):
    geom = configure_geometry_module(row)
    return geom.build_magnets(
        float(row.inner_center_radius_mm), float(row.outer_center_radius_mm),
        float(row.inner_center_offset_deg), float(row.outer_center_offset_deg),
    )


def save_preview(low: pd.Series, high: pd.Series) -> Path:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    path = OUTPUT / "matched_pair_geometry_preview.png"
    fig, axes = plt.subplots(1, 2, figsize=(12, 5.8), constrained_layout=True)
    for ax, row, name in [(axes[0], low, "Low ripple"), (axes[1], high, "High ripple")]:
        for item in magnets_for(row):
            pts = np.asarray(item["points"])
            pts = np.vstack([pts, pts[0]])
            color = "#d62728" if int(item["pole"]) % 2 == 0 else "#1f77b4"
            hatch = None if item["layer"] == "inner" else "//"
            ax.fill(pts[:, 0], pts[:, 1], color=color, alpha=.72,
                    hatch=hatch, edgecolor="black", linewidth=.5)
        for radius, style in [(8, ":"), (31.5, "-"), (32, "--")]:
            ax.add_patch(plt.Circle((0, 0), radius, fill=False, color="gray", ls=style, lw=.8))
        ax.set_aspect("equal"); ax.set_xlim(-34, 34); ax.set_ylim(-34, 34)
        ax.grid(alpha=.15); ax.set_xlabel("x [mm]"); ax.set_ylabel("y [mm]")
        ax.set_title(
            f"{name}: run {int(row.run)}\n"
            f"inner={row.inner_angle_deg:.1f} deg, ripple={row.loaded_torque_ripple_pct:.2f}%, "
            f"T={row.loaded_torque_mean_Nm:.2f} N*m"
        )
    fig.savefig(path, dpi=180, bbox_inches="tight")
    plt.close(fig)
    return path


def prepare() -> None:
    OUTPUT.mkdir(exist_ok=True)
    frame = pd.read_csv(SOURCE)
    low, high, candidates = select_matched_pair(frame)
    plan = pd.DataFrame([low, high])
    plan.insert(0, "case_label", ["low_ripple", "high_ripple"])
    plan.to_csv(PLAN_CSV, index=False, encoding="utf-8-sig")
    candidates.head(50).to_csv(OUTPUT / "matched_pair_candidate_ranking.csv", index=False, encoding="utf-8-sig")
    preview = save_preview(low, high)
    config = {
        "source": str(SOURCE),
        "plan": str(PLAN_CSV),
        "current_peak_A": 10.0,
        "commutation_offset_deg": 35.0,
        "rotor_initial_angle_deg": -10.0,
        "theta_start_deg": 0.0,
        "theta_stop_deg": 28.0,
        "theta_step_deg": 2.0,
        "airgap_sample_step_deg": 0.5,
        "selection_intent": "large inner-angle/ripple difference with matched torque, magnet area, and nuisance variables",
        "femm_requires_explicit_flag": "--run-femm",
    }
    CONFIG_JSON.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Prepared only; FEMM was not opened.\nPlan: {PLAN_CSV}\nPreview: {preview}")
    print(plan[["case_label", "run", "inner_angle_deg", "loaded_torque_mean_Nm",
                "loaded_torque_ripple_pct", "total_magnet_area_mm2"]].to_string(index=False))


def sample_airgap(femm, radius_mm: float, step_deg: float) -> list[dict[str, float]]:
    rows = []
    for angle_deg in np.arange(0, 360 + step_deg / 2, step_deg):
        angle = math.radians(float(angle_deg))
        x, y = radius_mm * math.cos(angle), radius_mm * math.sin(angle)
        bx, by = femm.mo_getb(x, y)
        br = bx * math.cos(angle) + by * math.sin(angle)
        bt = -bx * math.sin(angle) + by * math.cos(angle)
        rows.append({
            "airgap_angle_deg": float(angle_deg), "Bx_T": bx, "By_T": by,
            "Br_T": br, "Bt_T": bt,
            "maxwell_shear_Pa": br * bt / MU0,
            "maxwell_radial_pressure_Pa": (br * br - bt * bt) / (2 * MU0),
        })
    return rows


def set_currents(femm, base, theta_deg: float, current: float, beta_deg: float) -> None:
    theta_e = math.radians(base.POLE_PAIRS * (theta_deg + beta_deg))
    currents = (
        -current * math.sin(theta_e),
        -current * math.sin(theta_e - 2 * math.pi / 3),
        -current * math.sin(theta_e + 2 * math.pi / 3),
    )
    for name, value in zip(base.COIL_NAMES, currents):
        femm.mi_setcurrent(name, value)


def run_femm(resume: bool = True) -> None:
    """Run 0 A and 10 A matched-pair solves; called only by --run-femm."""
    import femm
    import analyze_axis_shortedge_ccf_python as axis
    import generate_v_ipm_motor as base

    if not PLAN_CSV.exists():
        prepare()
    plan = pd.read_csv(PLAN_CSV)
    cfg = json.loads(CONFIG_JSON.read_text(encoding="utf-8"))
    radius = (base.PM_R + base.SEAL + base.CORE_RI) / 2
    base.CORE = "M-19 Steel"
    base.define_materials = axis.define_axis_shortedge_materials
    base.add_windings = axis.add_axis_shortedge_windings
    femm.openfemm(1)
    try:
        for _, row in plan.iterrows():
            case_dir = OUTPUT / f"{row.case_label}_run_{int(row.run):03d}"
            case_dir.mkdir(exist_ok=True)
            done = case_dir / "FEMM_COMPLETE.json"
            if resume and done.exists():
                print(f"Skip completed: {case_dir.name}")
                continue
            geom = configure_geometry_module(row)
            base.draw_rotor = geom.draw_rotor_factory(
                float(row.inner_center_radius_mm), float(row.outer_center_radius_mm),
                float(row.inner_center_offset_deg), float(row.outer_center_offset_deg),
            )
            torque_path = case_dir / "torque_sweep_partial.csv"
            airgap_path = case_dir / "airgap_field_and_maxwell_stress_partial.csv"
            torque_rows = pd.read_csv(torque_path).to_dict("records") if resume and torque_path.exists() else []
            all_airgap = pd.read_csv(airgap_path).to_dict("records") if resume and airgap_path.exists() else []
            completed_states = {
                (str(item["state"]), round(float(item["theta_deg"]), 9))
                for item in torque_rows
            }
            theta_values = np.arange(cfg["theta_start_deg"], cfg["theta_stop_deg"] + 1e-9, cfg["theta_step_deg"])
            for current_label, current, theta_list in [
                ("no_load", 0.0, [0.0]),
                ("loaded", cfg["current_peak_A"], theta_values),
            ]:
                for theta in theta_list:
                    state_key = (current_label, round(float(theta), 9))
                    if resume and state_key in completed_states:
                        print(f"  Resume skip: {case_dir.name} {current_label} theta={float(theta):g}")
                        continue
                    base.build_base_model(case_dir, rotor_mech_angle_deg=cfg["rotor_initial_angle_deg"] + float(theta))
                    set_currents(femm, base, float(theta), current, cfg["commutation_offset_deg"])
                    femm.mi_analyze(); femm.mi_loadsolution()
                    femm.mo_groupselectblock(1)
                    torque = femm.mo_blockintegral(22)
                    femm.mo_clearblock()
                    sampled = sample_airgap(femm, radius, cfg["airgap_sample_step_deg"])
                    for item in sampled:
                        item.update({"state": current_label, "theta_deg": float(theta), "current_peak_A": current})
                    all_airgap.extend(sampled)
                    torque_rows.append({"state": current_label, "theta_deg": float(theta), "torque_Nm": torque})
                    # FEMM bitmap capture is intentionally excluded here.  In
                    # minimized/automation mode it can produce a 1x1 bitmap and
                    # terminate the COM server.  Visual exports are a separate
                    # post-solve step after all numeric checkpoints complete.
                    femm.mo_close(); femm.mi_close()
                    # Persist every solved rotor position for crash-safe resume.
                    pd.DataFrame(torque_rows).to_csv(torque_path, index=False)
                    pd.DataFrame(all_airgap).to_csv(airgap_path, index=False)
                    print(f"  Saved: {case_dir.name} {current_label} theta={float(theta):g}", flush=True)
            pd.DataFrame(torque_rows).to_csv(case_dir / "torque_sweep.csv", index=False)
            pd.DataFrame(all_airgap).to_csv(case_dir / "airgap_field_and_maxwell_stress.csv", index=False)
            done.write_text(json.dumps({"run": int(row.run), "status": "complete"}, indent=2), encoding="utf-8")
            print(f"Completed: {case_dir.name}")
    finally:
        femm.closefemm()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-femm", action="store_true", help="Explicitly launch and run FEMM.")
    parser.add_argument("--no-resume", action="store_true", help="Recompute completed cases.")
    args = parser.parse_args()
    prepare()
    if args.run_femm:
        run_femm(resume=not args.no_resume)


if __name__ == "__main__":
    main()
