"""Full 0--12 degree validation of rotor-yoke thickness candidates at 50 A."""
from __future__ import annotations
import argparse, csv, math, os, shutil, traceback
from pathlib import Path
import femm
import numpy as np

ROOT=Path("outer_rotor_36s30p_hairpin/rotor_yoke_thickness_screen_50A")
CANDIDATES={"radial":[3.75,4.00,4.25],"halbach_3seg":[2.25,2.50,2.75]}
FIELDS=("design","yoke_thickness_mm","mechanical_angle_deg","torque_Nm","gap_fundamental_peak_T",
        "rotor_yoke_B_p99_T","rotor_yoke_B_max_T","elapsed_s")

def polar(r,a):return r*math.cos(a),r*math.sin(a)
def done(path):
    if not path.exists():return set()
    with path.open(encoding="utf-8-sig",newline="") as f:return {(float(r["yoke_thickness_mm"]),int(float(r["mechanical_angle_deg"]))) for r in csv.DictReader(f)}
def append(path,row):
    new=not path.exists()
    with path.open("a",encoding="utf-8-sig",newline="") as f:
        w=csv.DictWriter(f,fieldnames=FIELDS)
        if new:w.writeheader()
        w.writerow(row);f.flush();os.fsync(f.fileno())
def solve(design,t,angle,source,work):
    import time
    started=time.time();shutil.copy2(source,work);femm.opendocument(str(work.resolve()))
    try:
        femm.mi_selectgroup(1);femm.mi_moverotate(0,0,angle);femm.mi_clearselected()
        e=math.radians(-15*angle);vals=(50*math.sin(e),50*math.sin(e+2*math.pi/3),50*math.sin(e-2*math.pi/3))
        for p,v in zip("ABC",vals):femm.mi_modifycircprop(p,1,v)
        femm.mi_analyze(1);femm.mi_loadsolution();femm.mo_groupselectblock(1);torque=float(femm.mo_blockintegral(22));femm.mo_clearblock()
        ar=np.linspace(0,2*np.pi,720,endpoint=False);gap=[]
        for a in ar:
            bx,by=femm.mo_getb(*polar(65.65,a));gap.append(bx*math.cos(a)+by*math.sin(a))
        fundamental=float(2*abs((np.fft.rfft(gap)/len(gap))[15]));radius=70+t/2;y=[]
        for deg in np.arange(0,360,1.0):
            bx,by=femm.mo_getb(*polar(radius,math.radians(float(deg))));y.append(math.hypot(bx,by))
        y=np.asarray(y);femm.mo_close();femm.mi_close()
        return {"design":design,"yoke_thickness_mm":t,"mechanical_angle_deg":angle,"torque_Nm":torque,
                "gap_fundamental_peak_T":fundamental,"rotor_yoke_B_p99_T":float(np.percentile(y,99)),
                "rotor_yoke_B_max_T":float(y.max()),"elapsed_s":time.time()-started}
    finally:
        try:femm.mo_close()
        except Exception:pass
        try:femm.mi_close()
        except Exception:pass
def run(design):
    out=ROOT/design/"full_angle_validation";out.mkdir(parents=True,exist_ok=True);result=out/"candidate_angle_map.csv";complete=done(result)
    femm.openfemm(1)
    try:
        for t in CANDIDATES[design]:
            source=ROOT/design/f"{design}_yoke_{t:.2f}mm_50A_angle0deg.fem"
            for angle in range(13):
                if (t,angle) in complete:continue
                print(f"START {design} t={t:.2f}mm angle={angle}",flush=True)
                row=solve(design,t,angle,source,out/"working.fem");append(result,row)
                print(f"DONE t={t:.2f} angle={angle} T={row['torque_Nm']:.6g} Ry99={row['rotor_yoke_B_p99_T']:.5g}T",flush=True)
    finally:femm.closefemm()
if __name__=="__main__":
    p=argparse.ArgumentParser();p.add_argument("--design",choices=tuple(CANDIDATES),required=True);a=p.parse_args()
    try:run(a.design)
    except Exception:
        (ROOT/a.design/"full_angle_validation_error.log").write_text(traceback.format_exc(),encoding="utf-8");raise
