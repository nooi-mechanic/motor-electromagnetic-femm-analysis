"""Screen rotor back-iron thickness from 1.5 to 5.0 mm at 50 A, angle 0."""
from __future__ import annotations

import argparse
import csv
import math
import os
import time
import traceback
from pathlib import Path

import femm
import numpy as np
import generate_outer_rotor_36s30p_hairpin as gen

ROOT = Path("outer_rotor_36s30p_hairpin/rotor_yoke_thickness_screen_50A")
THICKNESSES_MM = [round(1.5 + 0.25*i, 2) for i in range(15)]
FIELDS = ("design", "yoke_thickness_mm", "rotor_outer_radius_mm", "torque_Nm",
          "gap_fundamental_peak_T", "rotor_yoke_B_mean_T", "rotor_yoke_B_p95_T",
          "rotor_yoke_B_p99_T", "rotor_yoke_B_max_T", "elapsed_s", "attempt")


def polar(r, a):
    return r*math.cos(a), r*math.sin(a)


def completed(path: Path) -> set[float]:
    if not path.exists(): return set()
    with path.open(encoding="utf-8-sig", newline="") as f:
        return {float(r["yoke_thickness_mm"]) for r in csv.DictReader(f)}


def append(path: Path, row: dict) -> None:
    new = not path.exists()
    with path.open("a", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        if new: w.writeheader()
        w.writerow(row); f.flush(); os.fsync(f.fileno())


def build(design: str, thickness: float, model: Path) -> None:
    gen.MOTOR_OUTER_R = gen.ROTOR_YOKE_INNER_R + thickness
    if design == "radial":
        gen.generate(model, magnetization="radial", phase_current=50, current_angle_deg=90)
    else:
        gen.generate(model, magnetization="halbach", halbach_segments=3,
                     phase_current=50, current_angle_deg=90)


def solve(design: str, thickness: float, model: Path, attempt: int) -> dict:
    build(design, thickness, model)
    started = time.time()
    femm.openfemm(1)
    try:
        femm.opendocument(str(model.resolve()))
        femm.mi_analyze(1); femm.mi_loadsolution()
        femm.mo_groupselectblock(1); torque = float(femm.mo_blockintegral(22)); femm.mo_clearblock()
        angles = np.linspace(0, 2*np.pi, 720, endpoint=False)
        gap = []
        for a in angles:
            bx, by = femm.mo_getb(*polar(65.65, a)); gap.append(bx*math.cos(a)+by*math.sin(a))
        coeff = np.fft.rfft(gap)/len(gap); fundamental = float(2*abs(coeff[15]))
        radius = gen.ROTOR_YOKE_INNER_R + thickness/2
        yoke = []
        for deg in np.arange(0, 360, 1.0):
            bx, by = femm.mo_getb(*polar(radius, math.radians(float(deg))))
            yoke.append(math.hypot(bx, by))
        y = np.asarray(yoke)
        femm.mo_close(); femm.mi_close()
        return {"design": design, "yoke_thickness_mm": thickness,
                "rotor_outer_radius_mm": gen.ROTOR_YOKE_INNER_R+thickness,
                "torque_Nm": torque, "gap_fundamental_peak_T": fundamental,
                "rotor_yoke_B_mean_T": float(y.mean()), "rotor_yoke_B_p95_T": float(np.percentile(y,95)),
                "rotor_yoke_B_p99_T": float(np.percentile(y,99)), "rotor_yoke_B_max_T": float(y.max()),
                "elapsed_s": time.time()-started, "attempt": attempt}
    finally:
        try: femm.mo_close()
        except Exception: pass
        try: femm.mi_close()
        except Exception: pass
        try: femm.closefemm()
        except Exception: pass


def run(design: str) -> None:
    out = ROOT/design; out.mkdir(parents=True, exist_ok=True)
    result = out/"thickness_screen.csv"; done = completed(result)
    for thickness in THICKNESSES_MM:
        if thickness in done: continue
        model = out/f"{design}_yoke_{thickness:.2f}mm_50A_angle0deg.fem"
        for attempt in range(1,4):
            try:
                print(f"START {design} thickness={thickness:.2f}mm attempt={attempt}", flush=True)
                row = solve(design, thickness, model, attempt); append(result,row)
                print(f"DONE t={thickness:.2f}mm T={row['torque_Nm']:.6g}Nm "
                      f"Ry99={row['rotor_yoke_B_p99_T']:.5g}T Rymax={row['rotor_yoke_B_max_T']:.5g}T "
                      f"{row['elapsed_s']:.1f}s", flush=True)
                break
            except Exception:
                print(traceback.format_exc(), flush=True)
                time.sleep(2)
        else:
            (out/f"failed_{thickness:.2f}mm.log").write_text(traceback.format_exc(), encoding="utf-8")


if __name__ == "__main__":
    p=argparse.ArgumentParser(); p.add_argument("--design", choices=("radial","halbach_3seg"), required=True)
    run(p.parse_args().design)
