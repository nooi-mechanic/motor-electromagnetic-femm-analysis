"""Resumable synchronous rotor-position sweep for the 36S30P radial rotor."""

from __future__ import annotations

import csv
import math
import time
import traceback
from pathlib import Path
import shutil

import femm


ROOT = Path("outer_rotor_36s30p_hairpin")
MODEL = ROOT / "radial_rotation_base.fem"
OUT = ROOT / "radial_15A_position_sweep_0p2deg"
WORK_MODEL = OUT / "radial_position_working.fem"
CSV_PATH = OUT / "radial_15A_torque_vs_position.csv"
CURRENT_PEAK_A = 15.0
POLE_PAIRS = 15
ROTOR_GROUP = 1
ANGLES_DEG = [round(0.2 * i, 10) for i in range(51)]  # 0--10 mechanical deg, inclusive
FIELDS = ("mechanical_angle_deg", "electrical_angle_deg", "current_angle_sign",
          "phase_A_A", "phase_B_A", "phase_C_A", "torque_Nm", "elapsed_s")


def currents(mechanical_angle_deg: float, sign: int) -> tuple[float, float, float, float]:
    electrical = sign * POLE_PAIRS * mechanical_angle_deg
    a = math.radians(electrical)
    return electrical, CURRENT_PEAK_A * math.sin(a), CURRENT_PEAK_A * math.sin(a + 2*math.pi/3), CURRENT_PEAK_A * math.sin(a - 2*math.pi/3)


def solve(angle_deg: float, sign: int) -> dict[str, float | int]:
    started = time.time()
    # FEMM saves the open document during analysis. Refresh a disposable model
    # for every point so rotor rotation can never accumulate or alter the source.
    shutil.copy2(MODEL, WORK_MODEL)
    print(f"START angle={angle_deg:.1f} deg, sign={sign:+d}", flush=True)
    femm.opendocument(str(WORK_MODEL.resolve()))
    try:
        femm.mi_selectgroup(ROTOR_GROUP)
        femm.mi_moverotate(0, 0, angle_deg)
        femm.mi_clearselected()
        electrical, ia, ib, ic = currents(angle_deg, sign)
        for phase, value in zip("ABC", (ia, ib, ic)):
            femm.mi_modifycircprop(phase, 1, value)
        femm.mi_analyze(1)
        femm.mi_loadsolution()
        femm.mo_groupselectblock(ROTOR_GROUP)
        torque = float(femm.mo_blockintegral(22))
        femm.mo_clearblock()
        femm.mo_close()
        row = {
            "mechanical_angle_deg": angle_deg, "electrical_angle_deg": electrical,
            "current_angle_sign": sign, "phase_A_A": ia, "phase_B_A": ib,
            "phase_C_A": ic, "torque_Nm": torque, "elapsed_s": time.time() - started,
        }
        print(f"DONE angle={angle_deg:.1f} deg, sign={sign:+d}, T={torque:.6g} N m, "
              f"{row['elapsed_s']:.1f} s", flush=True)
        return row
    finally:
        try:
            femm.mi_close()
        except Exception:
            pass


def append(row: dict[str, float | int]) -> None:
    new = not CSV_PATH.exists()
    with CSV_PATH.open("a", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        if new:
            writer.writeheader()
        writer.writerow(row)
        f.flush()


def completed() -> dict[float, dict[str, str]]:
    if not CSV_PATH.exists():
        return {}
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        return {round(float(r["mechanical_angle_deg"]), 10): r for r in csv.DictReader(f)}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    femm.openfemm(1)
    try:
        done = completed()
        # At +0.2 mechanical degree, select the phase-advance sign that keeps
        # torque nearest the 0-degree q-axis value. Calibration rows are kept separately.
        calibration_path = OUT / "phase_sign_calibration.csv"
        if not calibration_path.exists() or len(list(csv.DictReader(calibration_path.open(encoding="utf-8-sig")))) < 2:
            trials = []
            with calibration_path.open("w", encoding="utf-8-sig", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=FIELDS); writer.writeheader()
                for s in (+1, -1):
                    row = solve(0.2, s); trials.append(row); writer.writerow(row); f.flush()
            sign = max(trials, key=lambda r: float(r["torque_Nm"]))["current_angle_sign"]
            (OUT / "selected_phase_sign.txt").write_text(str(sign), encoding="ascii")
            print("Calibration: " + ", ".join(f"sign {r['current_angle_sign']:+d}: {r['torque_Nm']:.6g} N m" for r in trials), flush=True)
        else:
            sign = int((OUT / "selected_phase_sign.txt").read_text(encoding="ascii").strip())
        print(f"Selected synchronous current-angle sign: {sign:+d}", flush=True)

        for angle in ANGLES_DEG:
            if angle in done:
                continue
            row = solve(angle, sign)
            append(row)
            print(f"{angle:.1f} deg: T={row['torque_Nm']:.6g} N m, {row['elapsed_s']:.1f} s", flush=True)

        rows = list(completed().values())
        torque = [float(r["torque_Nm"]) for r in rows]
        avg = sum(torque) / len(torque)
        ripple = max(torque) - min(torque)
        report = (f"points={len(torque)}\nmean_torque_Nm={avg:.12g}\n"
                  f"min_torque_Nm={min(torque):.12g}\nmax_torque_Nm={max(torque):.12g}\n"
                  f"peak_to_peak_Nm={ripple:.12g}\nripple_percent={100*ripple/abs(avg):.12g}\n")
        (OUT / "radial_15A_position_report.txt").write_text(report, encoding="utf-8")
        print(report, end="", flush=True)
    finally:
        femm.closefemm()


if __name__ == "__main__":
    try:
        main()
    except Exception:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT / "sweep_error.log").write_text(traceback.format_exc(), encoding="utf-8")
        raise
