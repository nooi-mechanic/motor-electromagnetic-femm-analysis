"""Resumable 0--50 A current/position map with torque and flux diagnostics.

Each FEM solve starts from a disposable copy of a rotation-safe base model.
The result row is committed only after the raw flux waveform has been saved.
"""

from __future__ import annotations

import argparse
import csv
import math
import os
import shutil
import time
import traceback
from pathlib import Path

import femm
import numpy as np


ROOT = Path("outer_rotor_36s30p_hairpin")
POLE_PAIRS = 15
ROTOR_GROUP = 1
CURRENT_LEVELS = list(range(0, 21)) + list(range(22, 51, 2))
ANGLES_DEG = list(range(0, 13))
GAP_ANGLES_RAD = np.linspace(0, 2 * np.pi, 1440, endpoint=False)
LEAK_ANGLES_RAD = np.linspace(0, 2 * np.pi, 720, endpoint=False)
SAMPLE_ANGLES_DEG = np.arange(0, 360, 2.0)
STATOR_RADII_MM = (34.5, 42.0, 50.0, 58.0, 62.5)
ROTOR_YOKE_RADIUS_MM = 72.5

DESIGNS = {
    "radial": ROOT / "radial_rotation_base.fem",
    "halbach_3seg": ROOT / "halbach_3seg_rotation_base.fem",
}

FIELDS = (
    "design", "current_peak_A", "mechanical_angle_deg", "electrical_angle_deg",
    "phase_A_A", "phase_B_A", "phase_C_A", "torque_Nm", "torque_per_A_Nm_per_A",
    "gap_fundamental_peak_T", "gap_fundamental_phase_deg", "gap_rms_T",
    "gap_peak_abs_T", "gap_thd", "gap_harmonic_30_peak_T", "gap_harmonic_45_peak_T",
    "external_leakage_rms_T", "external_leakage_peak_T",
    "stator_steel_sample_count", "stator_B_mean_T", "stator_B_rms_T",
    "stator_B_p95_T", "stator_B_p99_T", "stator_B_max_T",
    "stator_fraction_gt_1p6", "stator_fraction_gt_1p8", "stator_fraction_gt_2p0",
    "rotor_yoke_B_mean_T", "rotor_yoke_B_rms_T", "rotor_yoke_B_p95_T",
    "rotor_yoke_B_p99_T", "rotor_yoke_B_max_T", "elapsed_s", "attempt",
)


def polar(r: float, angle_rad: float) -> tuple[float, float]:
    return r * math.cos(angle_rad), r * math.sin(angle_rad)


def radial_b(r: float, angle_rad: float) -> float:
    bx, by = femm.mo_getb(*polar(r, angle_rad))
    return bx * math.cos(angle_rad) + by * math.sin(angle_rad)


def bmag_and_mu(r: float, angle_deg: float) -> tuple[float, float]:
    a = math.radians(angle_deg)
    values = femm.mo_getpointvalues(*polar(r, a))
    bx, by = float(values[1]), float(values[2])
    mu1, mu2 = float(values[9]), float(values[10])
    return math.hypot(bx, by), max(abs(mu1), abs(mu2))


def fft_metrics(signal: np.ndarray) -> dict[str, float]:
    coeff = np.fft.rfft(signal) / len(signal)
    peak = 2 * np.abs(coeff)
    fundamental = peak[POLE_PAIRS]
    harmonic_sq = sum(float(peak[k])**2 for k in range(1, len(peak)) if k != POLE_PAIRS)
    return {
        "fundamental_peak": float(fundamental),
        "fundamental_phase": float(np.degrees(np.angle(coeff[POLE_PAIRS]))),
        "rms": float(np.sqrt(np.mean(signal**2))),
        "peak": float(np.max(np.abs(signal))),
        "thd": float(math.sqrt(harmonic_sq) / fundamental) if fundamental else float("nan"),
        "h30": float(peak[30]), "h45": float(peak[45]),
    }


def stats(values: list[float]) -> dict[str, float]:
    a = np.asarray(values, dtype=float)
    return {
        "mean": float(a.mean()), "rms": float(np.sqrt(np.mean(a*a))),
        "p95": float(np.percentile(a, 95)), "p99": float(np.percentile(a, 99)),
        "max": float(a.max()),
    }


def phase_currents(current: float, mechanical_angle: float) -> tuple[float, float, float, float]:
    electrical = -POLE_PAIRS * mechanical_angle
    a = math.radians(electrical)
    return electrical, current*math.sin(a), current*math.sin(a+2*math.pi/3), current*math.sin(a-2*math.pi/3)


def load_completed(path: Path) -> set[tuple[int, int]]:
    if not path.exists():
        return set()
    with path.open(encoding="utf-8-sig", newline="") as f:
        return {(int(float(r["current_peak_A"])), int(float(r["mechanical_angle_deg"]))) for r in csv.DictReader(f)}


def append_row(path: Path, row: dict) -> None:
    new = not path.exists()
    with path.open("a", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            writer.writeheader()
        writer.writerow(row)
        f.flush()
        os.fsync(f.fileno())


def solve_point(design: str, base: Path, work: Path, wave_dir: Path,
                current: int, angle: int, attempt: int) -> dict:
    started = time.time()
    shutil.copy2(base, work)
    print(f"START design={design} I={current}A angle={angle}deg attempt={attempt}", flush=True)
    femm.opendocument(str(work.resolve()))
    try:
        femm.mi_selectgroup(ROTOR_GROUP)
        femm.mi_moverotate(0, 0, angle)
        femm.mi_clearselected()
        electrical, ia, ib, ic = phase_currents(current, angle)
        if abs(ia + ib + ic) > 1e-9:
            raise RuntimeError("Unbalanced phase currents")
        for phase, value in zip("ABC", (ia, ib, ic)):
            femm.mi_modifycircprop(phase, 1, value)
        femm.mi_analyze(1)
        femm.mi_loadsolution()

        femm.mo_groupselectblock(ROTOR_GROUP)
        torque = float(femm.mo_blockintegral(22))
        femm.mo_clearblock()

        gap = np.array([radial_b(65.65, a) for a in GAP_ANGLES_RAD])
        leakage = np.array([radial_b(78.0, a) for a in LEAK_ANGLES_RAD])
        gm = fft_metrics(gap)

        stator_values = []
        for radius in STATOR_RADII_MM:
            for deg in SAMPLE_ANGLES_DEG:
                b, mu = bmag_and_mu(radius, float(deg))
                if mu > 2.0:  # reject air/copper; retain nonlinear steel elements
                    stator_values.append(b)
        if len(stator_values) < 100:
            raise RuntimeError(f"Too few stator-steel samples: {len(stator_values)}")
        ss = stats(stator_values)
        rotor_values = [bmag_and_mu(ROTOR_YOKE_RADIUS_MM, float(deg))[0] for deg in SAMPLE_ANGLES_DEG]
        rs = stats(rotor_values)

        if not np.isfinite(torque) or not np.all(np.isfinite(gap)):
            raise RuntimeError("Non-finite FEM result")
        wave_path = wave_dir / f"I{current:02d}A_angle{angle:02d}deg.npz"
        temp_path = wave_path.with_suffix(".tmp.npz")
        np.savez_compressed(temp_path, gap_angle_deg=np.degrees(GAP_ANGLES_RAD), gap_Br_T=gap,
                            leakage_angle_deg=np.degrees(LEAK_ANGLES_RAD), leakage_Br_T=leakage)
        os.replace(temp_path, wave_path)

        elapsed = time.time() - started
        row = {
            "design": design, "current_peak_A": current, "mechanical_angle_deg": angle,
            "electrical_angle_deg": electrical, "phase_A_A": ia, "phase_B_A": ib, "phase_C_A": ic,
            "torque_Nm": torque, "torque_per_A_Nm_per_A": torque/current if current else "",
            "gap_fundamental_peak_T": gm["fundamental_peak"],
            "gap_fundamental_phase_deg": gm["fundamental_phase"], "gap_rms_T": gm["rms"],
            "gap_peak_abs_T": gm["peak"], "gap_thd": gm["thd"],
            "gap_harmonic_30_peak_T": gm["h30"], "gap_harmonic_45_peak_T": gm["h45"],
            "external_leakage_rms_T": float(np.sqrt(np.mean(leakage**2))),
            "external_leakage_peak_T": float(np.max(np.abs(leakage))),
            "stator_steel_sample_count": len(stator_values), "stator_B_mean_T": ss["mean"],
            "stator_B_rms_T": ss["rms"], "stator_B_p95_T": ss["p95"],
            "stator_B_p99_T": ss["p99"], "stator_B_max_T": ss["max"],
            "stator_fraction_gt_1p6": float(np.mean(np.asarray(stator_values) > 1.6)),
            "stator_fraction_gt_1p8": float(np.mean(np.asarray(stator_values) > 1.8)),
            "stator_fraction_gt_2p0": float(np.mean(np.asarray(stator_values) > 2.0)),
            "rotor_yoke_B_mean_T": rs["mean"], "rotor_yoke_B_rms_T": rs["rms"],
            "rotor_yoke_B_p95_T": rs["p95"], "rotor_yoke_B_p99_T": rs["p99"],
            "rotor_yoke_B_max_T": rs["max"], "elapsed_s": elapsed, "attempt": attempt,
        }
        print(f"DONE I={current}A angle={angle}deg T={torque:.6g}Nm "
              f"Bgap1={gm['fundamental_peak']:.5g}T Bst99={ss['p99']:.5g}T {elapsed:.1f}s", flush=True)
        return row
    finally:
        try:
            femm.mo_close()
        except Exception:
            pass
        try:
            femm.mi_close()
        except Exception:
            pass


def run(design: str) -> None:
    base = DESIGNS[design]
    out = ROOT / f"nonlinear_current_angle_map_0to50A_{design}"
    wave_dir = out / "flux_waveforms"
    out.mkdir(parents=True, exist_ok=True)
    wave_dir.mkdir(parents=True, exist_ok=True)
    result_path = out / "current_angle_map.csv"
    failure_path = out / "failed_cases.csv"
    work = out / "working_model.fem"
    completed = load_completed(result_path)
    total = len(CURRENT_LEVELS) * len(ANGLES_DEG)
    print(f"PLAN design={design} total={total} completed={len(completed)} pending={total-len(completed)}", flush=True)

    femm.openfemm(1)
    try:
        for current in CURRENT_LEVELS:
            for angle in ANGLES_DEG:
                if (current, angle) in completed:
                    continue
                last_error = ""
                for attempt in range(1, 4):
                    try:
                        row = solve_point(design, base, work, wave_dir, current, angle, attempt)
                        append_row(result_path, row)
                        completed.add((current, angle))
                        break
                    except Exception:
                        last_error = traceback.format_exc()
                        print(f"RETRY I={current}A angle={angle}deg attempt={attempt}\n{last_error}", flush=True)
                        try:
                            femm.closefemm()
                        except Exception:
                            pass
                        time.sleep(2)
                        femm.openfemm(1)
                else:
                    new = not failure_path.exists()
                    with failure_path.open("a", encoding="utf-8-sig", newline="") as f:
                        w = csv.writer(f)
                        if new:
                            w.writerow(("design", "current_peak_A", "mechanical_angle_deg", "error"))
                        w.writerow((design, current, angle, last_error.replace("\n", " | ")))
                        f.flush(); os.fsync(f.fileno())
                    print(f"FAILED I={current}A angle={angle}deg after 3 attempts; continuing", flush=True)

            done_now = len(load_completed(result_path))
            print(f"CHECKPOINT design={design} current={current}A completed={done_now}/{total}", flush=True)
    finally:
        try:
            femm.closefemm()
        except Exception:
            pass
    print(f"COMPLETE design={design} completed={len(load_completed(result_path))}/{total}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--design", choices=tuple(DESIGNS), required=True)
    args = parser.parse_args()
    run(args.design)
