"""Compare 2.5 mm rotor-yoke designs at 50 A over 0--12 mechanical degrees."""
from __future__ import annotations
import argparse, csv, math, os, shutil, time, traceback
from pathlib import Path
import femm
import numpy as np

ROOT = Path("outer_rotor_36s30p_hairpin/half_rotor_yoke_2p5mm")
BASES = {"radial": ROOT/"radial_half_yoke_base.fem",
         "halbach_3seg": ROOT/"halbach_3seg_half_yoke_base.fem"}
ANGLES = range(13)
FIELDS = ("design","current_peak_A","mechanical_angle_deg","torque_Nm","gap_fundamental_peak_T",
          "rotor_yoke_B_mean_T","rotor_yoke_B_p95_T","rotor_yoke_B_p99_T","rotor_yoke_B_max_T","elapsed_s")

def polar(r,a): return r*math.cos(a),r*math.sin(a)
def bmag(r,deg):
    bx,by=femm.mo_getb(*polar(r,math.radians(deg))); return math.hypot(bx,by)
def completed(path):
    if not path.exists(): return set()
    with path.open(encoding="utf-8-sig",newline="") as f:return {int(float(x["mechanical_angle_deg"])) for x in csv.DictReader(f)}
def append(path,row):
    new=not path.exists()
    with path.open("a",encoding="utf-8-sig",newline="") as f:
        w=csv.DictWriter(f,fieldnames=FIELDS)
        if new:w.writeheader()
        w.writerow(row);f.flush();os.fsync(f.fileno())
def solve(design,base,work,angle):
    started=time.time();shutil.copy2(base,work);femm.opendocument(str(work.resolve()))
    try:
        femm.mi_selectgroup(1);femm.mi_moverotate(0,0,angle);femm.mi_clearselected()
        e=math.radians(-15*angle); vals=(50*math.sin(e),50*math.sin(e+2*math.pi/3),50*math.sin(e-2*math.pi/3))
        for p,v in zip("ABC",vals):femm.mi_modifycircprop(p,1,v)
        femm.mi_analyze(1);femm.mi_loadsolution();femm.mo_groupselectblock(1);t=float(femm.mo_blockintegral(22));femm.mo_clearblock()
        ar=np.linspace(0,2*np.pi,720,endpoint=False);gap=[]
        for a in ar:
            bx,by=femm.mo_getb(*polar(65.65,a));gap.append(bx*math.cos(a)+by*math.sin(a))
        c=np.fft.rfft(gap)/len(gap);fund=float(2*abs(c[15]))
        ry=np.array([bmag(71.25,d) for d in np.arange(0,360,1.0)])
        if angle==0:
            preserved=ROOT/f"{design}_half_yoke_50A_angle0deg.fem"
            femm.mo_close();femm.mi_saveas(str(preserved.resolve()));femm.mi_analyze(1);femm.mi_loadsolution();femm.mo_close()
        else:femm.mo_close()
        femm.mi_close()
        return {"design":design,"current_peak_A":50,"mechanical_angle_deg":angle,"torque_Nm":t,
                "gap_fundamental_peak_T":fund,"rotor_yoke_B_mean_T":float(ry.mean()),
                "rotor_yoke_B_p95_T":float(np.percentile(ry,95)),"rotor_yoke_B_p99_T":float(np.percentile(ry,99)),
                "rotor_yoke_B_max_T":float(ry.max()),"elapsed_s":time.time()-started}
    finally:
        try:femm.mo_close()
        except Exception:pass
        try:femm.mi_close()
        except Exception:pass
def run(design):
    out=ROOT/design;out.mkdir(parents=True,exist_ok=True);csvp=out/"half_yoke_50A_angle_map.csv";done=completed(csvp)
    femm.openfemm(1)
    try:
        for angle in ANGLES:
            if angle in done:continue
            print(f"START {design} 50A angle={angle}",flush=True)
            row=solve(design,BASES[design],out/"working.fem",angle);append(csvp,row)
            print(f"DONE angle={angle} T={row['torque_Nm']:.6g}Nm Ry99={row['rotor_yoke_B_p99_T']:.5g}T {row['elapsed_s']:.1f}s",flush=True)
    finally:femm.closefemm()
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--design",choices=tuple(BASES),required=True);a=p.parse_args()
    try:run(a.design)
    except Exception:
        (ROOT/f"{a.design}_error.log").write_text(traceback.format_exc(),encoding="utf-8");raise
