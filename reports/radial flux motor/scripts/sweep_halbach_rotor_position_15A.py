"""Resumable 0--10 degree synchronous sweep for the 36S30P 3-seg Halbach rotor."""

from __future__ import annotations

import csv
import math
import shutil
import time
import traceback
from pathlib import Path

import femm

ROOT = Path("outer_rotor_36s30p_hairpin")
MODEL = ROOT / "halbach_3seg_rotation_base.fem"
OUT = ROOT / "halbach_3seg_15A_position_sweep_0p2deg_10deg"
WORK_MODEL = OUT / "halbach_position_working.fem"
CSV_PATH = OUT / "halbach_3seg_15A_torque_vs_position.csv"
CURRENT_PEAK_A = 15.0
POLE_PAIRS = 15
ROTOR_GROUP = 1
ANGLES_DEG = [round(0.2*i, 10) for i in range(51)]
FIELDS = ("mechanical_angle_deg", "electrical_angle_deg", "current_angle_sign",
          "phase_A_A", "phase_B_A", "phase_C_A", "torque_Nm", "elapsed_s")


def currents(mechanical_angle_deg: float, sign: int):
    electrical = sign * POLE_PAIRS * mechanical_angle_deg
    a = math.radians(electrical)
    return electrical, CURRENT_PEAK_A*math.sin(a), CURRENT_PEAK_A*math.sin(a+2*math.pi/3), CURRENT_PEAK_A*math.sin(a-2*math.pi/3)


def solve(angle_deg: float, sign: int):
    started = time.time()
    shutil.copy2(MODEL, WORK_MODEL)
    print(f"START angle={angle_deg:.1f} deg, sign={sign:+d}", flush=True)
    femm.opendocument(str(WORK_MODEL.resolve()))
    try:
        femm.mi_selectgroup(ROTOR_GROUP); femm.mi_moverotate(0, 0, angle_deg); femm.mi_clearselected()
        electrical, ia, ib, ic = currents(angle_deg, sign)
        for phase, value in zip("ABC", (ia, ib, ic)): femm.mi_modifycircprop(phase, 1, value)
        femm.mi_analyze(1); femm.mi_loadsolution()
        femm.mo_groupselectblock(ROTOR_GROUP); torque = float(femm.mo_blockintegral(22)); femm.mo_clearblock(); femm.mo_close()
        row = {"mechanical_angle_deg": angle_deg, "electrical_angle_deg": electrical,
               "current_angle_sign": sign, "phase_A_A": ia, "phase_B_A": ib, "phase_C_A": ic,
               "torque_Nm": torque, "elapsed_s": time.time()-started}
        print(f"DONE angle={angle_deg:.1f} deg, sign={sign:+d}, T={torque:.6g} N m, {row['elapsed_s']:.1f} s", flush=True)
        return row
    finally:
        try: femm.mi_close()
        except Exception: pass


def append(path: Path, row, new_fields=FIELDS):
    new = not path.exists()
    with path.open("a", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=new_fields)
        if new: w.writeheader()
        w.writerow(row); f.flush()


def completed():
    if not CSV_PATH.exists(): return {}
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
        return {round(float(r["mechanical_angle_deg"]), 10): r for r in csv.DictReader(f)}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    femm.openfemm(1)
    try:
        cal = OUT / "phase_sign_calibration.csv"
        if not cal.exists() or len(list(csv.DictReader(cal.open(encoding="utf-8-sig")))) < 2:
            if cal.exists(): cal.unlink()
            trials = []
            for sign in (+1, -1):
                row = solve(0.2, sign); trials.append(row); append(cal, row)
            sign = max(trials, key=lambda r: float(r["torque_Nm"]))["current_angle_sign"]
            (OUT/"selected_phase_sign.txt").write_text(str(sign), encoding="ascii")
            print("Calibration: " + ", ".join(f"sign {r['current_angle_sign']:+d}: {r['torque_Nm']:.6g} N m" for r in trials), flush=True)
        else:
            sign = int((OUT/"selected_phase_sign.txt").read_text(encoding="ascii").strip())
        print(f"Selected synchronous current-angle sign: {sign:+d}", flush=True)
        done = completed()
        for angle in ANGLES_DEG:
            if angle in done: continue
            row = solve(angle, sign); append(CSV_PATH, row)
        rows = list(completed().values()); torque = [float(r["torque_Nm"]) for r in rows]
        avg = sum(torque)/len(torque); pp = max(torque)-min(torque)
        report = (f"points={len(torque)}\nmean_torque_Nm={avg:.12g}\nmin_torque_Nm={min(torque):.12g}\n"
                  f"max_torque_Nm={max(torque):.12g}\npeak_to_peak_Nm={pp:.12g}\nripple_percent={100*pp/abs(avg):.12g}\n")
        (OUT/"halbach_3seg_15A_position_report.txt").write_text(report, encoding="utf-8")
        print(report, end="", flush=True)
    finally:
        femm.closefemm()


if __name__ == "__main__":
    try: main()
    except Exception:
        OUT.mkdir(parents=True, exist_ok=True)
        (OUT/"sweep_error.log").write_text(traceback.format_exc(), encoding="utf-8")
        raise
