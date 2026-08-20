"""Solve and compare radial and three-segment internal-field Halbach rotors."""

from __future__ import annotations

import argparse
import csv
import math
import time
from pathlib import Path

import femm
import numpy as np


ROOT = Path("outer_rotor_36s30p_hairpin")
SAMPLES = 720
POLE_PAIRS = 15
AIRGAP_R = 65.65
LEAKAGE_R = 78.0


def radial_b(r: float, angle: float) -> float:
    x, y = r * math.cos(angle), r * math.sin(angle)
    bx, by = femm.mo_getb(x, y)
    return bx * math.cos(angle) + by * math.sin(angle)


def metrics(signal: np.ndarray) -> dict[str, float]:
    fft = np.fft.rfft(signal) / len(signal)
    peak = 2 * np.abs(fft)
    fundamental = peak[POLE_PAIRS]
    harmonic_sq = sum(peak[k] ** 2 for k in range(1, len(peak)) if k != POLE_PAIRS)
    return {
        "peak_abs_T": float(np.max(np.abs(signal))),
        "rms_T": float(np.sqrt(np.mean(signal ** 2))),
        "fundamental_peak_T": float(fundamental),
        "thd": float(math.sqrt(harmonic_sq) / fundamental),
    }


def solve_case(name: str, path: Path) -> tuple[np.ndarray, np.ndarray, float, float]:
    started = time.time()
    femm.opendocument(str(path.resolve()))
    femm.mi_analyze(1)
    femm.mi_loadsolution()
    angles = np.linspace(0, 2 * np.pi, SAMPLES, endpoint=False)
    gap = np.array([radial_b(AIRGAP_R, a) for a in angles])
    leakage = np.array([radial_b(LEAKAGE_R, a) for a in angles])
    femm.mo_groupselectblock(1)
    torque = float(femm.mo_blockintegral(22))
    femm.mo_clearblock()
    femm.mo_close()
    femm.mi_close()
    elapsed = time.time() - started
    print(f"{name}: solved in {elapsed:.1f} s", flush=True)
    return gap, leakage, elapsed, torque


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--radial-model", type=Path, default=ROOT / "radial.fem")
    parser.add_argument("--halbach-model", type=Path, default=ROOT / "halbach_3seg.fem")
    parser.add_argument("--output-prefix", default="radial_halbach")
    args = parser.parse_args()
    cases = {"radial": args.radial_model, "halbach_3seg": args.halbach_model}
    ROOT.mkdir(parents=True, exist_ok=True)
    femm.openfemm(1)
    results = {}
    try:
        for name, path in cases.items():
            gap, leakage, elapsed, torque = solve_case(name, path)
            results[name] = {
                "gap": gap,
                "leakage": leakage,
                "elapsed_s": elapsed,
                "torque_Nm": torque,
                **{f"gap_{k}": v for k, v in metrics(gap).items()},
                **{f"leakage_{k}": v for k, v in metrics(leakage).items()},
            }
    finally:
        femm.closefemm()

    angles_deg = np.arange(SAMPLES) * 360 / SAMPLES
    with (ROOT / f"{args.output_prefix}_waveforms.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(("mechanical_angle_deg", "radial_gap_Br_T", "halbach_gap_Br_T",
                         "radial_external_Br_T", "halbach_external_Br_T"))
        for i, angle in enumerate(angles_deg):
            writer.writerow((angle, results["radial"]["gap"][i], results["halbach_3seg"]["gap"][i],
                             results["radial"]["leakage"][i], results["halbach_3seg"]["leakage"][i]))

    scalar_keys = [k for k in results["radial"] if k not in ("gap", "leakage")]
    with (ROOT / f"{args.output_prefix}_metrics.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        writer.writerow(("metric", "radial", "halbach_3seg", "change_percent"))
        for key in scalar_keys:
            a, b = results["radial"][key], results["halbach_3seg"][key]
            writer.writerow((key, a, b, 100 * (b / a - 1) if a else ""))

    rg = results["radial"]["gap_fundamental_peak_T"]
    hg = results["halbach_3seg"]["gap_fundamental_peak_T"]
    rl = results["radial"]["leakage_rms_T"]
    hl = results["halbach_3seg"]["leakage_rms_T"]
    report = (
        "Radial vs 3-segment Halbach no-load comparison\n"
        f"Air-gap fundamental peak: {rg:.6g} -> {hg:.6g} T ({100*(hg/rg-1):+.2f}%)\n"
        f"Air-gap THD: {results['radial']['gap_thd']:.4f} -> {results['halbach_3seg']['gap_thd']:.4f}\n"
        f"External leakage RMS: {rl:.6g} -> {hl:.6g} T ({100*(hl/rl-1):+.2f}%)\n"
        f"Torque: {results['radial']['torque_Nm']:.6g} -> {results['halbach_3seg']['torque_Nm']:.6g} N m\n"
    )
    (ROOT / f"{args.output_prefix}_report.txt").write_text(report, encoding="utf-8")
    print(report, end="")


if __name__ == "__main__":
    main()
