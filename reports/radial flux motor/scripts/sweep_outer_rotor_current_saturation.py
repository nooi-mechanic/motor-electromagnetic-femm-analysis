"""Resumable 1--15 A q-axis current sweep for radial and 3-segment Halbach rotors."""

from __future__ import annotations

import argparse
import csv
import math
import time
import traceback
from pathlib import Path

import femm
import numpy as np


ROOT = Path("outer_rotor_36s30p_hairpin")
OUT = ROOT / "current_saturation_1to15A"
CASES = {
    "radial": ROOT / "radial.fem",
    "halbach_3seg": ROOT / "halbach_3seg.fem",
}
FIELDS = (
    "design", "current_peak_A", "phase_A_A", "phase_B_A", "phase_C_A",
    "torque_Nm", "torque_per_A_Nm_per_A", "gap_fundamental_peak_T",
    "gap_rms_T", "gap_thd", "external_leakage_rms_T",
    "external_leakage_peak_T", "stator_sample_max_B_T",
    "rotor_yoke_sample_max_B_T", "elapsed_s",
)
POLE_PAIRS = 15


def polar(r: float, angle_deg: float) -> tuple[float, float]:
    a = math.radians(angle_deg)
    return r * math.cos(a), r * math.sin(a)


def radial_b(r: float, angle_rad: float) -> float:
    x, y = r * math.cos(angle_rad), r * math.sin(angle_rad)
    bx, by = femm.mo_getb(x, y)
    return bx * math.cos(angle_rad) + by * math.sin(angle_rad)


def bmag(r: float, angle_deg: float) -> float:
    bx, by = femm.mo_getb(*polar(r, angle_deg))
    return math.hypot(bx, by)


def signal_metrics(signal: np.ndarray) -> tuple[float, float, float, float]:
    fft = np.fft.rfft(signal) / len(signal)
    peak = 2 * np.abs(fft)
    fundamental = float(peak[POLE_PAIRS])
    harmonic_sq = sum(float(peak[k]) ** 2 for k in range(1, len(peak)) if k != POLE_PAIRS)
    return fundamental, float(np.sqrt(np.mean(signal**2))), math.sqrt(harmonic_sq) / fundamental, float(np.max(np.abs(signal)))


def completed(csv_path: Path) -> set[tuple[str, int]]:
    if not csv_path.exists():
        return set()
    with csv_path.open(encoding="utf-8-sig", newline="") as f:
        return {(r["design"], int(float(r["current_peak_A"]))) for r in csv.DictReader(f)}


def append_row(csv_path: Path, row: dict[str, float | str]) -> None:
    new = not csv_path.exists()
    with csv_path.open("a", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            writer.writeheader()
        writer.writerow(row)
        f.flush()


def solve_design(design: str, model: Path, currents: list[int], csv_path: Path) -> None:
    done = completed(csv_path)
    pending = [i for i in currents if (design, i) not in done]
    if not pending:
        print(f"{design}: already complete", flush=True)
        return
    femm.openfemm(1)
    try:
        femm.opendocument(str(model.resolve()))
        for current in pending:
            started = time.time()
            ia = 0.0
            ib = current * math.sqrt(3) / 2
            ic = -ib
            femm.mi_modifycircprop("A", 1, ia)
            femm.mi_modifycircprop("B", 1, ib)
            femm.mi_modifycircprop("C", 1, ic)
            femm.mi_analyze(1)
            femm.mi_loadsolution()

            femm.mo_groupselectblock(1)
            torque = float(femm.mo_blockintegral(22))
            femm.mo_clearblock()

            angles = np.linspace(0, 2 * np.pi, 180, endpoint=False)
            gap = np.array([radial_b(65.65, a) for a in angles])
            leakage = np.array([radial_b(78.0, a) for a in angles])
            gap_fund, gap_rms, gap_thd, _ = signal_metrics(gap)

            # Sampling locations cover stator yoke, tooth bodies, and rotor yoke.
            stator_samples = [bmag(34.5, a) for a in np.arange(0, 360, 2.5)]
            stator_samples += [bmag(50.0, a) for a in np.arange(0, 360, 2.5)]
            rotor_samples = [bmag(72.5, a) for a in np.arange(0, 360, 2.5)]
            elapsed = time.time() - started
            row = {
                "design": design, "current_peak_A": current,
                "phase_A_A": ia, "phase_B_A": ib, "phase_C_A": ic,
                "torque_Nm": torque, "torque_per_A_Nm_per_A": torque/current,
                "gap_fundamental_peak_T": gap_fund, "gap_rms_T": gap_rms,
                "gap_thd": gap_thd,
                "external_leakage_rms_T": float(np.sqrt(np.mean(leakage**2))),
                "external_leakage_peak_T": float(np.max(np.abs(leakage))),
                "stator_sample_max_B_T": max(stator_samples),
                "rotor_yoke_sample_max_B_T": max(rotor_samples),
                "elapsed_s": elapsed,
            }
            append_row(csv_path, row)
            femm.mo_close()
            print(f"{design} {current:02d} A: T={torque:.6g} N m, T/I={torque/current:.6g}, "
                  f"Bstator={max(stator_samples):.4g} T, leak={row['external_leakage_rms_T']:.4g} T, "
                  f"{elapsed:.1f} s", flush=True)
        femm.mi_close()
    finally:
        femm.closefemm()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-current", type=int, default=1)
    parser.add_argument("--max-current", type=int, default=15)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    csv_path = OUT / "current_saturation_sweep.csv"
    currents = list(range(args.min_current, args.max_current + 1))
    for design, model in CASES.items():
        solve_design(design, model, currents, csv_path)
    print(f"Complete: {csv_path.resolve()}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "sweep_error.log").write_text(traceback.format_exc(), encoding="utf-8")
        raise
