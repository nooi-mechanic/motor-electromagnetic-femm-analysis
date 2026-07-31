from pathlib import Path

import nbformat as nbf


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "double_layer_ccf_55to90_dnn_analysis.ipynb"


def md(text):
    return nbf.v4.new_markdown_cell(text.strip())


def code(text):
    return nbf.v4.new_code_cell(text.strip())


nb = nbf.v4.new_notebook()
nb["metadata"] = {
    "kernelspec": {
        "display_name": "pyFEMM 2 (.venv)",
        "language": "python",
        "name": "python3",
    },
    "language_info": {"name": "python", "version": "3.12"},
}

nb["cells"] = [
    md(
        """
# 더블레이어 IPM 55–90° CCF + DNN 최적설계 분석

이 노트북의 목적은 50개 설계점 자체에서 최적점을 고르는 것이 아니다.

1. 신규 55–90° CCF 50점과 기존 70–90° CCF 50점을 결합
2. 총 100개 FEMM 결과로 DNN surrogate 학습
3. 55–90° 전체 범위에서 형상검사 통과 후보 10,000점 예측
4. 다음 세 파레토를 계산
   - 평균토크 최대–절대 리플 최소
   - 평균토크 최대–자석 사용량 최소
   - 평균토크 최대–리플 최소–자석 사용량 최소
5. 싱글레이어 FEMM 결과와 비교하고 재검증 후보 선정

> DNN 후보의 출력은 FEMM 해석값이 아니므로 최종 후보는 다시 FEMM으로 검증해야 한다.
"""
    ),
    code(
        """
from pathlib import Path
import warnings

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.express as px
import plotly.io as pio
from IPython.display import display
from scipy.stats import qmc
from sklearn.compose import TransformedTargetRegressor
from sklearn.exceptions import ConvergenceWarning
from sklearn.metrics import r2_score, root_mean_squared_error
from sklearn.model_selection import RepeatedKFold
from sklearn.neural_network import MLPRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

import generate_v_ipm_motor as motor_base
from generate_double_layer_ccf_50 import RANGES as BASE_RANGES, evaluate

warnings.filterwarnings("ignore", category=ConvergenceWarning)
warnings.filterwarnings("ignore", message="Glyph .* missing")
sns.set_theme(style="whitegrid", context="notebook")
plt.rcParams["figure.figsize"] = (9, 5.5)
pd.options.display.float_format = "{:.4f}".format
pio.renderers.default = "notebook_connected"

ROOT = Path.cwd()
if not (ROOT / "double_layer_ccf_55to90_50_results").exists():
    ROOT = Path("C:/Users/139/Documents/pyFEMM 2")

NEW_DIR = ROOT / "double_layer_ccf_55to90_50_results"
OLD_DIR = ROOT / "double_layer_ccf_50_results"
SINGLE_DIR = ROOT / "doe_axis_shortedge_results"

new50 = pd.read_csv(NEW_DIR / "double_layer_ccf_summary.csv")
old50 = pd.read_csv(OLD_DIR / "double_layer_ccf_summary.csv")
single50 = pd.read_csv(SINGLE_DIR / "axis_shortedge_ccf_summary.csv")
new50["dataset"] = "New CCF 55–90°"
old50["dataset"] = "Old CCF 70–90°"
data = pd.concat([new50, old50], ignore_index=True)

factors = [
    "total_thickness_mm", "inner_length_mm",
    "v_angle_deg", "layer_normal_gap_mm",
]
factor_labels = ["Total thickness", "Inner length", "V angle", "Layer gap"]
mean_col = "loaded_torque_mean_Nm"
ripple_col = "loaded_torque_pkpk_Nm"
targets = [mean_col, ripple_col]

RANGES = dict(BASE_RANGES)
RANGES["v_angle_deg"] = (55.0, 90.0)
print("FEMM training samples:", len(data))
print(data.dataset.value_counts())
"""
    ),
    md("## 1. FEMM 데이터 완전성 및 범위"),
    code(
        """
checks = []
for label, frame, directory in [
    ("55–90°", new50, NEW_DIR), ("70–90°", old50, OLD_DIR)
]:
    for run in frame.run.astype(int):
        path = directory / f"run_{run:03d}" / "axis_shortedge_loaded_sweep.csv"
        n = len(pd.read_csv(path)) if path.exists() else 0
        checks.append((label, run, n, "OK" if n == 15 else "CHECK"))
checks = pd.DataFrame(checks, columns=["dataset", "run", "points", "status"])
display(checks.groupby(["dataset", "status"]).size().to_frame("designs"))
assert len(data) == 100 and (checks.points == 15).all()
display(data[factors + targets].describe().T)
"""
    ),
    md("## 2. 실제 FEMM 100점의 분포"),
    code(
        """
fig, axes = plt.subplots(1, 2, figsize=(14, 5.5))
sns.scatterplot(
    data=data, x="v_angle_deg", y=mean_col,
    hue="dataset", ax=axes[0], s=55,
)
sns.scatterplot(
    data=data, x="v_angle_deg", y=ripple_col,
    hue="dataset", ax=axes[1], s=55,
)
axes[0].set(xlabel="V angle [deg]", ylabel="Mean torque [Nm]")
axes[1].set(xlabel="V angle [deg]", ylabel="Ripple pk-pk [Nm]")
plt.tight_layout()
plt.show()
"""
    ),
    md("## 3. DNN surrogate 반복 교차검증"),
    code(
        """
X = data[factors].to_numpy(dtype=float)
y = data[targets].to_numpy(dtype=float)

def make_dnn(seed):
    network = Pipeline([
        ("scale_x", StandardScaler()),
        ("dnn", MLPRegressor(
            hidden_layer_sizes=(48, 24, 12),
            activation="tanh",
            solver="lbfgs",
            alpha=1.0,
            max_iter=5000,
            random_state=seed,
        )),
    ])
    return TransformedTargetRegressor(
        regressor=network, transformer=StandardScaler()
    )

cv = RepeatedKFold(n_splits=5, n_repeats=5, random_state=20260803)
pred_sum = np.zeros_like(y)
pred_count = np.zeros(len(y), dtype=int)
for fold, (train_idx, test_idx) in enumerate(cv.split(X)):
    model = make_dnn(1000 + fold)
    model.fit(X[train_idx], y[train_idx])
    pred_sum[test_idx] += model.predict(X[test_idx])
    pred_count[test_idx] += 1
cv_pred = pred_sum / pred_count[:, None]

cv_metrics = pd.DataFrame({
    "Repeated-CV R2": [
        r2_score(y[:, j], cv_pred[:, j]) for j in range(2)
    ],
    "Repeated-CV RMSE": [
        root_mean_squared_error(y[:, j], cv_pred[:, j])
        for j in range(2)
    ],
}, index=["Mean torque [Nm]", "Ripple pk-pk [Nm]"])
display(cv_metrics)

fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))
for j, title in enumerate(["Mean torque", "Torque ripple"]):
    axes[j].scatter(y[:, j], cv_pred[:, j], s=40, alpha=0.7)
    lo = min(y[:, j].min(), cv_pred[:, j].min())
    hi = max(y[:, j].max(), cv_pred[:, j].max())
    axes[j].plot([lo, hi], [lo, hi], "--", color="0.25")
    axes[j].set(
        xlabel="FEMM [Nm]", ylabel="Repeated-CV prediction [Nm]",
        title=title,
    )
plt.tight_layout()
plt.show()
"""
    ),
    md("## 4. 55–90° 형상검사 통과 LHS 후보 10,000점"),
    code(
        """
cache = ROOT / "double_layer_55to90_dnn_candidates_10000.csv"
n_candidates = 10_000
if cache.exists() and len(pd.read_csv(cache)) == n_candidates:
    candidates = pd.read_csv(cache)
    print(f"Loaded {len(candidates):,} cached candidates")
else:
    names = list(RANGES)
    lower = np.array([RANGES[name][0] for name in names])
    upper = np.array([RANGES[name][1] for name in names])
    sampler = qmc.LatinHypercube(d=4, seed=20260803)
    valid = []
    tested = 0
    while len(valid) < n_candidates:
        batch = qmc.scale(sampler.random(12_000), lower, upper)
        for values in batch:
            tested += 1
            row = evaluate(
                tested,
                {name: float(value) for name, value in zip(names, values)},
            )
            if row["geometry_status"] == "OK":
                valid.append(row)
                if len(valid) == n_candidates:
                    break
    candidates = pd.DataFrame(valid)
    candidates["candidate"] = np.arange(1, len(candidates) + 1)
    print(f"Tested {tested:,}; accepted {len(candidates):,}")
display(candidates[factors + [
    "outer_bridge_min_mm", "shaft_clearance_min_mm",
    "other_magnet_gap_min_mm"
]].describe().T)
"""
    ),
    md("## 5. DNN 30개 앙상블 예측과 총 불확실성"),
    code(
        """
candidate_X = candidates[factors].to_numpy(dtype=float)
ensemble = []
for seed in range(30):
    model = make_dnn(2000 + seed)
    model.fit(X, y)
    ensemble.append(model.predict(candidate_X))
ensemble = np.stack(ensemble)
pred = ensemble.mean(axis=0)
ensemble_std = ensemble.std(axis=0, ddof=1)
cv_rmse = cv_metrics["Repeated-CV RMSE"].to_numpy(dtype=float)
total_unc = np.sqrt(ensemble_std**2 + cv_rmse[None, :]**2)

candidates["pred_mean_torque_Nm"] = pred[:, 0]
candidates["pred_ripple_pkpk_Nm"] = pred[:, 1]
candidates["unc_mean_torque_Nm"] = total_unc[:, 0]
candidates["unc_ripple_pkpk_Nm"] = total_unc[:, 1]
candidates["conservative_mean_Nm"] = pred[:, 0] - total_unc[:, 0]
candidates["conservative_ripple_Nm"] = pred[:, 1] + total_unc[:, 1]

MAGNET_FACTOR = 8 * (0.5 + 0.5 * 0.8 * 0.8)
candidates["magnet_area_total_mm2"] = (
    MAGNET_FACTOR
    * candidates.total_thickness_mm
    * candidates.inner_length_mm
)
candidates["magnet_volume_total_cm3"] = (
    candidates.magnet_area_total_mm2 * motor_base.DEPTH / 1000
)
candidates["torque_per_magnet_Nm_cm3"] = (
    candidates.pred_mean_torque_Nm
    / candidates.magnet_volume_total_cm3
)
"""
    ),
    md("## 6. 평균토크 최대–절대 리플 최소 파레토"),
    code(
        """
def fast_pareto_2d(frame, maximize, minimize):
    ordered = frame.sort_values(
        [maximize, minimize], ascending=[False, True]
    )
    best = np.inf
    selected = []
    for idx, row in ordered.iterrows():
        if row[minimize] < best:
            selected.append(idx)
            best = row[minimize]
    mask = pd.Series(False, index=frame.index)
    mask.loc[selected] = True
    return mask

candidates["torque_ripple_pareto"] = fast_pareto_2d(
    candidates, "pred_mean_torque_Nm", "pred_ripple_pkpk_Nm"
)
tr_front = candidates[candidates.torque_ripple_pareto].copy()
tr_front = tr_front.sort_values("pred_mean_torque_Nm")

fig, ax = plt.subplots(figsize=(10, 6.5))
ax.scatter(
    candidates.pred_mean_torque_Nm,
    candidates.pred_ripple_pkpk_Nm,
    s=8, alpha=0.08, label="10,000 DNN candidates",
)
ax.plot(
    tr_front.pred_mean_torque_Nm, tr_front.pred_ripple_pkpk_Nm,
    "-o", color="crimson", lw=2, ms=3, label="Predicted Pareto",
)
ax.scatter(data[mean_col], data[ripple_col], marker="x", color="black",
           s=45, label="100 FEMM training points")
ax.set(xlabel="Mean torque [Nm]", ylabel="Ripple pk-pk [Nm]",
       title="Torque–ripple Pareto, V angle 55–90°")
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md("## 7. 자석 사용량 최소–평균토크 최대 파레토"),
    code(
        """
candidates["magnet_torque_pareto"] = fast_pareto_2d(
    candidates, "pred_mean_torque_Nm", "magnet_volume_total_cm3"
)
mt_front = candidates[candidates.magnet_torque_pareto].copy()
mt_front = mt_front.sort_values("magnet_volume_total_cm3")

fig, ax = plt.subplots(figsize=(10, 6.5))
sc = ax.scatter(
    candidates.magnet_volume_total_cm3,
    candidates.pred_mean_torque_Nm,
    c=candidates.pred_ripple_pkpk_Nm,
    cmap="viridis", s=8, alpha=0.12,
)
ax.plot(
    mt_front.magnet_volume_total_cm3, mt_front.pred_mean_torque_Nm,
    "-o", color="crimson", lw=2, ms=3, label="Magnet–torque Pareto",
)
ax.set(xlabel="Total magnet volume [cm³]",
       ylabel="Predicted mean torque [Nm]",
       title="Minimum magnet usage vs maximum mean torque")
fig.colorbar(sc, ax=ax, label="Predicted ripple pk-pk [Nm]")
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md("## 8. 토크–리플–자석량 3목적 파레토"),
    code(
        """
mean = candidates.pred_mean_torque_Nm.to_numpy()
ripple = candidates.pred_ripple_pkpk_Nm.to_numpy()
volume = candidates.magnet_volume_total_cm3.to_numpy()
keep = np.ones(len(candidates), dtype=bool)
for i in range(len(candidates)):
    dominated = (
        (mean >= mean[i])
        & (ripple <= ripple[i])
        & (volume <= volume[i])
        & (
            (mean > mean[i])
            | (ripple < ripple[i])
            | (volume < volume[i])
        )
    )
    keep[i] = not dominated.any()
candidates["three_objective_pareto"] = keep
front3 = candidates[candidates.three_objective_pareto].copy()
print("3-objective Pareto designs:", len(front3))

fig = px.scatter_3d(
    front3,
    x="magnet_volume_total_cm3",
    y="pred_ripple_pkpk_Nm",
    z="pred_mean_torque_Nm",
    color="v_angle_deg",
    color_continuous_scale="Plasma",
    hover_name="candidate",
    hover_data={
        "total_thickness_mm": ":.4f",
        "inner_length_mm": ":.4f",
        "v_angle_deg": ":.3f",
        "layer_normal_gap_mm": ":.4f",
        "unc_mean_torque_Nm": ":.3f",
        "unc_ripple_pkpk_Nm": ":.3f",
        "outer_bridge_min_mm": ":.3f",
        "other_magnet_gap_min_mm": ":.3f",
    },
    labels={
        "magnet_volume_total_cm3": "Magnet volume [cm³]",
        "pred_ripple_pkpk_Nm": "Ripple pk-pk [Nm]",
        "pred_mean_torque_Nm": "Mean torque [Nm]",
        "v_angle_deg": "V angle [deg]",
    },
    title="Interactive three-objective predicted Pareto",
)
fig.update_traces(marker={"size": 4, "opacity": 0.8})
fig.update_layout(
    height=720,
    scene={
        "xaxis_title": "Magnet volume [cm³]",
        "yaxis_title": "Ripple pk-pk [Nm]",
        "zaxis_title": "Mean torque [Nm]",
        "dragmode": "orbit",
    },
)
fig.show()
"""
    ),
    md("## 9. 싱글레이어 대비 비교"),
    code(
        """
single50["magnet_volume_total_cm3"] = (
    8
    * single50.magnet_thickness_mm
    * single50.magnet_length_mm
    * motor_base.DEPTH / 1000
)
fig, axes = plt.subplots(1, 2, figsize=(14, 5.5))
axes[0].scatter(
    single50[mean_col], single50[ripple_col],
    s=40, alpha=0.6, label="Single-layer FEMM 50",
)
axes[0].scatter(
    data[mean_col], data[ripple_col],
    s=30, alpha=0.45, label="Double-layer FEMM 100",
)
axes[0].plot(
    tr_front.pred_mean_torque_Nm, tr_front.pred_ripple_pkpk_Nm,
    color="crimson", lw=2, label="Double-layer DNN Pareto",
)
axes[0].set(xlabel="Mean torque [Nm]", ylabel="Ripple pk-pk [Nm]",
            title="Torque–ripple comparison")
axes[0].legend()

axes[1].scatter(
    single50.magnet_volume_total_cm3, single50[mean_col],
    s=40, alpha=0.6, label="Single-layer FEMM 50",
)
axes[1].scatter(
    candidates.magnet_volume_total_cm3,
    candidates.pred_mean_torque_Nm,
    s=7, alpha=0.06, label="Double-layer DNN 10,000",
)
axes[1].plot(
    mt_front.magnet_volume_total_cm3, mt_front.pred_mean_torque_Nm,
    color="crimson", lw=2, label="Double-layer DNN Pareto",
)
axes[1].set(xlabel="Total magnet volume [cm³]",
            ylabel="Mean torque [Nm]",
            title="Magnet usage–torque comparison")
axes[1].legend()
plt.tight_layout()
plt.show()
"""
    ),
    md("## 10. FEMM 재검증 후보 선정"),
    code(
        """
def add_knee_distance(front, x, y, maximize_y=True):
    result = front.copy()
    xspan = result[x].max() - result[x].min()
    yspan = result[y].max() - result[y].min()
    result["x_loss"] = (result[x] - result[x].min()) / xspan
    if maximize_y:
        result["y_loss"] = (result[y].max() - result[y]) / yspan
    else:
        result["y_loss"] = (result[y] - result[y].min()) / yspan
    result["ideal_distance"] = np.hypot(result.x_loss, result.y_loss)
    return result

tr_ranked = add_knee_distance(
    tr_front, "pred_ripple_pkpk_Nm", "pred_mean_torque_Nm", True
)
mt_ranked = add_knee_distance(
    mt_front, "magnet_volume_total_cm3", "pred_mean_torque_Nm", True
)

validation = pd.concat([
    tr_ranked.nsmallest(3, "ideal_distance"),
    mt_ranked.nsmallest(3, "ideal_distance"),
    tr_front.nsmallest(1, "pred_ripple_pkpk_Nm"),
    tr_front.nlargest(1, "pred_mean_torque_Nm"),
]).drop_duplicates("candidate")

validation_cols = [
    "candidate", *factors, "magnet_center_offset_deg",
    "magnet_volume_total_cm3",
    "pred_mean_torque_Nm", "unc_mean_torque_Nm",
    "pred_ripple_pkpk_Nm", "unc_ripple_pkpk_Nm",
    "torque_per_magnet_Nm_cm3",
    "outer_bridge_min_mm", "other_magnet_gap_min_mm",
]
display(validation[validation_cols].set_index("candidate"))
"""
    ),
    md("## 11. 결과 저장"),
    code(
        """
candidates.to_csv(
    ROOT / "double_layer_55to90_dnn_candidates_10000.csv", index=False
)
tr_front.to_csv(
    ROOT / "double_layer_55to90_torque_ripple_pareto.csv", index=False
)
mt_front.to_csv(
    ROOT / "double_layer_55to90_magnet_torque_pareto.csv", index=False
)
front3.to_csv(
    ROOT / "double_layer_55to90_three_objective_pareto.csv", index=False
)
validation[validation_cols].to_csv(
    ROOT / "double_layer_55to90_femm_validation_candidates.csv", index=False
)
print("Saved DNN candidates, Pareto fronts, and FEMM validation candidates")
"""
    ),
    md(
        """
## 12. 최종 판단 방법

- DNN 파레토는 최적점 후보를 찾는 도구이며 최종 FEMM 결과가 아니다.
- 재검증 후보는 0–30°, 0.5° 간격으로 다시 계산한다.
- 후보별 commutation offset 30–40°를 재탐색한다.
- 싱글레이어와 비교할 때는 동일 전류뿐 아니라 자석 체적, 토크리플, 코깅토크,
  역기전력 THD, 반경력과 약계자 성능을 함께 평가해야 한다.
"""
    ),
]

nbf.write(nb, OUTPUT)
print(f"Created: {OUTPUT}")
