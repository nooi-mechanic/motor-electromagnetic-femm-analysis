from pathlib import Path

import nbformat as nbf


ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "double_layer_ccf_50_analysis.ipynb"


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
# 더블레이어 IPM 4인자 CCF 50점 분석

## 설계 정의

- 안쪽 자석: 기준 길이, 기준 총 두께의 1/2
- 바깥 자석: 안쪽 자석 대비 길이 80%, 두께 80%
- 레이어 수직 gap: 설계변수
- TIPGAP: 0.608 mm 고정
- 자석군 반경 이동: 1.0 mm 고정
- 자석 사용량: 기존 싱글레이어의 **82%**

## 먼저 보는 결론

- **리플 최소:** Run 33 — 37.60 Nm / 3.13 Nm
- **저리플 균형:** Run 22 — 42.39 Nm / 3.43 Nm
- **종합 균형:** Run 19 — 46.00 Nm / 5.33 Nm
- **평균토크 최대:** Run 15 — 49.06 Nm / 7.89 Nm

자석을 18% 줄였음에도 Run 19는 싱글레이어 균형점 Run 49의 평균토크를 거의 유지했다.
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
from IPython.display import display
from sklearn.compose import TransformedTargetRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import r2_score, root_mean_squared_error
from sklearn.model_selection import KFold, cross_val_predict
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import PolynomialFeatures, StandardScaler

warnings.filterwarnings("ignore", message="Glyph .* missing")
sns.set_theme(style="whitegrid", context="notebook")
plt.rcParams["figure.figsize"] = (9, 5.5)
pd.options.display.float_format = "{:.4f}".format

ROOT = Path.cwd()
if not (ROOT / "double_layer_ccf_50_results").exists():
    ROOT = Path("C:/Users/139/Documents/pyFEMM 2")

DOUBLE_DIR = ROOT / "double_layer_ccf_50_results"
DOUBLE_CSV = DOUBLE_DIR / "double_layer_ccf_summary.csv"
SINGLE_CSV = ROOT / "doe_axis_shortedge_results" / "axis_shortedge_ccf_summary.csv"

df = pd.read_csv(DOUBLE_CSV)
single = pd.read_csv(SINGLE_CSV)
factors = [
    "total_thickness_mm",
    "inner_length_mm",
    "v_angle_deg",
    "layer_normal_gap_mm",
]
factor_labels = ["Total thickness", "Inner length", "V angle", "Layer gap"]
mean_col = "loaded_torque_mean_Nm"
ripple_col = "loaded_torque_pkpk_Nm"
ripple_pct_col = "loaded_torque_ripple_pct"

print(f"Double-layer designs: {len(df)}")
print(f"Magnet usage ratio: {df.magnet_area_ratio_vs_single.iloc[0]:.0%}")
print(f"Operating points: {len(df)} × {int(df.completed_points.iloc[0])}")
"""
    ),
    md("## 1. 결과 완전성 검사"),
    code(
        """
checks = []
for run in df.run.astype(int):
    path = DOUBLE_DIR / f"run_{run:03d}" / "axis_shortedge_loaded_sweep.csv"
    rows = len(pd.read_csv(path)) if path.exists() else 0
    checks.append((run, rows, "OK" if rows == 15 else "CHECK"))
checks = pd.DataFrame(checks, columns=["run", "sweep_rows", "status"])
display(checks.status.value_counts().to_frame("design_count"))
assert len(df) == 50 and (checks.sweep_rows == 15).all()
print("검증 통과: 50개 설계 × 15개 각도 = 750개 FEMM 운전점")
"""
    ),
    md("## 2. 성능 순위"),
    code(
        """
show = factors + [mean_col, ripple_col, ripple_pct_col]
rename = {
    "total_thickness_mm": "Total thickness [mm]",
    "inner_length_mm": "Inner length [mm]",
    "v_angle_deg": "V angle [deg]",
    "layer_normal_gap_mm": "Layer gap [mm]",
    mean_col: "Mean torque [Nm]",
    ripple_col: "Ripple pk-pk [Nm]",
    ripple_pct_col: "Ripple [%]",
}
print("평균토크 상위 10개")
display(df.set_index("run").nlargest(10, mean_col)[show].rename(columns=rename))
print("절대 리플 하위 10개")
display(df.set_index("run").nsmallest(10, ripple_col)[show].rename(columns=rename))
"""
    ),
    md("## 3. 더블레이어 파레토 프론트"),
    code(
        """
def pareto_mask(frame, mean=mean_col, ripple=ripple_col):
    m = frame[mean].to_numpy()
    r = frame[ripple].to_numpy()
    return np.array([
        not np.any((m >= m[i]) & (r <= r[i]) & ((m > m[i]) | (r < r[i])))
        for i in range(len(frame))
    ])

df["pareto"] = pareto_mask(df)
front = df[df.pareto].sort_values(mean_col)

fig, ax = plt.subplots(figsize=(9, 6))
ax.scatter(df.loc[~df.pareto, mean_col], df.loc[~df.pareto, ripple_col],
           s=42, alpha=0.5, label="Dominated designs")
ax.plot(front[mean_col], front[ripple_col], "-o", color="crimson",
        lw=2, label="Double-layer Pareto")
for _, row in front.iterrows():
    ax.annotate(f"Run {int(row.run)}", (row[mean_col], row[ripple_col]),
                xytext=(4, 5), textcoords="offset points")
ax.set(xlabel="Mean torque [Nm]", ylabel="Ripple pk-pk [Nm]",
       title="Double-layer CCF: Pareto front")
ax.legend()
plt.tight_layout()
plt.show()
display(front.set_index("run")[show].rename(columns=rename))
"""
    ),
    md("## 4. 싱글레이어와 직접 비교"),
    code(
        """
single["pareto"] = pareto_mask(single)
single_front = single[single.pareto].sort_values(mean_col)

fig, ax = plt.subplots(figsize=(10, 6.5))
ax.scatter(single[mean_col], single[ripple_col], s=28, alpha=0.25,
           label="Single-layer 50 points")
ax.plot(single_front[mean_col], single_front[ripple_col], "--o",
        lw=1.8, ms=5, label="Single-layer Pareto")
ax.scatter(df[mean_col], df[ripple_col], s=28, alpha=0.25,
           label="Double-layer 50 points")
ax.plot(front[mean_col], front[ripple_col], "-o", color="crimson",
        lw=2.2, ms=5, label="Double-layer Pareto (82% magnet)")
ax.set(xlabel="Mean torque [Nm]", ylabel="Ripple pk-pk [Nm]",
       title="Single layer vs double layer")
ax.legend()
plt.tight_layout()
plt.show()

single_balance = single.loc[single.run == 49].iloc[0]
single_max = single.loc[single[mean_col].idxmax()]
comparison = pd.DataFrame([
    ["Single Run 49", 1.00, single_balance[mean_col], single_balance[ripple_col]],
    ["Double Run 22", 0.82, df.loc[df.run == 22, mean_col].iloc[0],
     df.loc[df.run == 22, ripple_col].iloc[0]],
    ["Double Run 19", 0.82, df.loc[df.run == 19, mean_col].iloc[0],
     df.loc[df.run == 19, ripple_col].iloc[0]],
    ["Single max", 1.00, single_max[mean_col], single_max[ripple_col]],
    ["Double Run 15", 0.82, df.loc[df.run == 15, mean_col].iloc[0],
     df.loc[df.run == 15, ripple_col].iloc[0]],
], columns=["Design", "Magnet ratio", "Mean torque [Nm]", "Ripple [Nm]"])
display(comparison.set_index("Design"))
"""
    ),
    md(
        """
### 비교 해석

- **Run 22:** 싱글레이어 Run 49보다 평균토크는 낮지만 자석을 18% 줄이면서 리플도 크게 감소한다.
- **Run 19:** 자석을 18% 줄이고도 싱글레이어 Run 49와 비슷한 평균토크를 유지한다. 리플은 약간 증가한다.
- **Run 15:** 싱글레이어 최대토크보다 평균토크가 약 4% 낮지만 리플은 더 작고 자석은 18% 적다.

따라서 더블레이어의 장점은 절대 최대토크 상승보다 **자석 사용량 대비 성능**에서 나타난다.
"""
    ),
    md("## 5. 상관관계와 2차 반응표면 민감도"),
    code(
        """
corr = df[factors + [mean_col, ripple_col, ripple_pct_col]].corr()
fig, ax = plt.subplots(figsize=(10, 7))
sns.heatmap(corr, annot=True, fmt=".2f", cmap="vlag", center=0,
            xticklabels=factor_labels + ["Mean torque", "Ripple", "Ripple %"],
            yticklabels=factor_labels + ["Mean torque", "Ripple", "Ripple %"],
            ax=ax)
ax.set_title("Double-layer correlation matrix")
plt.tight_layout()
plt.show()
"""
    ),
    code(
        """
X = df[factors]
cv = KFold(n_splits=5, shuffle=True, random_state=123)

def fit_quadratic(target):
    model = Pipeline([
        ("scale_x", StandardScaler()),
        ("poly", PolynomialFeatures(2, include_bias=False)),
        ("reg", LinearRegression()),
    ])
    wrapped = TransformedTargetRegressor(
        regressor=model, transformer=StandardScaler()
    )
    y = df[target].to_numpy()
    pred_cv = cross_val_predict(wrapped, X, y, cv=cv)
    wrapped.fit(X, y)
    fitted = wrapped.predict(X)
    inner = wrapped.regressor_
    terms = inner.named_steps["poly"].get_feature_names_out(factor_labels)
    effects = pd.Series(
        inner.named_steps["reg"].coef_, index=terms
    ).sort_values(key=np.abs, ascending=False)
    metrics = {
        "Training R2": r2_score(y, fitted),
        "CV R2": r2_score(y, pred_cv),
        "Training RMSE": root_mean_squared_error(y, fitted),
        "CV RMSE": root_mean_squared_error(y, pred_cv),
    }
    return metrics, effects

mean_metrics, mean_effects = fit_quadratic(mean_col)
ripple_metrics, ripple_effects = fit_quadratic(ripple_col)
display(pd.DataFrame({
    "Mean torque model": mean_metrics,
    "Ripple model": ripple_metrics,
}))

fig, axes = plt.subplots(1, 2, figsize=(14, 6))
for ax, effects, title in [
    (axes[0], mean_effects.head(10).sort_values(), "Mean torque effects"),
    (axes[1], ripple_effects.head(10).sort_values(), "Ripple effects"),
]:
    effects.plot.barh(
        ax=ax,
        color=["tab:blue" if value >= 0 else "tab:orange" for value in effects],
    )
    ax.axvline(0, color="0.2", lw=1)
    ax.set(xlabel="Standardized coefficient", title=title)
plt.tight_layout()
plt.show()
"""
    ),
    md(
        """
### 민감도 핵심

- **V각이 가장 강한 변수다.** V각이 커질수록 평균토크는 감소하지만 리플은 매우 강하게 감소한다.
- **안쪽 자석 길이**와 **총 두께**는 평균토크 증가에 유효하다.
- 새로 추가한 **레이어 gap**은 평균토크에 대한 단순 영향은 작고 리플에는 약한 증가 방향이다.
- 따라서 다음 최적화에서는 레이어 gap 범위를 무작정 넓히기보다 좋은 점 주변에서 좁혀 보는 것이 효율적이다.
"""
    ),
    md("## 6. 추천 설계의 실제 토크 파형"),
    code(
        """
recommended = [22, 19, 15, 33]
fig, ax = plt.subplots(figsize=(10, 6))
for run in recommended:
    sweep = pd.read_csv(
        DOUBLE_DIR / f"run_{run:03d}" / "axis_shortedge_loaded_sweep.csv"
    )
    ax.plot(sweep.theta_deg, sweep.torque_Nm, "-o", ms=4, label=f"Run {run}")
ax.set(xlabel="Mechanical angle [deg]", ylabel="Torque [Nm]",
       title="Recommended double-layer torque waveforms")
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md(
        """
## 7. 다음 단계 추천

1. **Run 22, 19, 15**를 0–30°, 0.5° 간격으로 재해석한다.
2. 각 설계의 commutation offset을 30–40°에서 다시 최적화한다.
3. 저리플 목적이면 Run 22, 토크/자석비 목적이면 Run 19를 기준 형상으로 선택한다.
4. 검증된 기준점 주변에서 범위를 좁혀 surrogate 또는 NSGA-II를 진행한다.

현재 2° 간격에서는 토크 최대·최소를 놓칠 수 있으므로 0.5° 검증 전에는 Run 22와 Run 41처럼 가까운 설계의 순위를 확정하지 않는다.
"""
    ),
]

nbf.write(nb, OUTPUT)
print(f"Created: {OUTPUT}")
