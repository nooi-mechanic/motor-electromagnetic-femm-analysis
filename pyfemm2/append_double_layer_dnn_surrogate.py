from pathlib import Path

import nbformat


ROOT = Path(__file__).resolve().parent
NOTEBOOK = ROOT / "double_layer_ccf_50_analysis.ipynb"
TAG = "double-layer-dnn-surrogate"


def md(text):
    cell = nbformat.v4.new_markdown_cell(text.strip())
    cell.metadata["tags"] = [TAG]
    return cell


def code(text):
    cell = nbformat.v4.new_code_cell(text.strip())
    cell.metadata["tags"] = [TAG]
    return cell


nb = nbformat.read(NOTEBOOK, as_version=4)
nb.cells = [
    cell for cell in nb.cells
    if TAG not in cell.get("metadata", {}).get("tags", [])
]

nb.cells.extend([
    md(
        """
# 8. DNN surrogate로 설계공간 10,000점 탐색

앞의 50점 파레토는 최종 최적해가 아니라 **DNN surrogate 학습용 FEMM DOE**다.

여기서는 GitHub의 `CCF_DNN_RANDOM1000_WORKFLOW.ipynb` 흐름을 현재 더블레이어 문제에 맞게 확장한다.

1. 실제 FEMM 50점으로 DNN 학습
2. 반복 교차검증으로 예측 성능 확인
3. 전체 설계범위에서 형상검사 통과 LHS 후보 10,000점 생성
4. 초기값이 다른 DNN 30개의 앙상블로 성능과 불확실성 예측
5. 평균토크 최대화·절대 리플 최소화 예측 파레토 추출
6. 최종 후보를 FEMM으로 재검증

> 아래 10,000점의 출력은 FEMM 결과가 아니라 DNN 예측값이다.
"""
    ),
    code(
        """
from scipy.stats import qmc
from sklearn.compose import TransformedTargetRegressor
from sklearn.exceptions import ConvergenceWarning
from sklearn.model_selection import RepeatedKFold
from sklearn.neural_network import MLPRegressor

from generate_double_layer_ccf_50 import RANGES, evaluate

warnings.filterwarnings("ignore", category=ConvergenceWarning)
dnn_targets = [mean_col, ripple_col]
X_dnn = df[factors].to_numpy(dtype=float)
y_dnn = df[dnn_targets].to_numpy(dtype=float)

def make_dnn(seed):
    network = Pipeline([
        ("scale_x", StandardScaler()),
        ("dnn", MLPRegressor(
            hidden_layer_sizes=(32, 16, 8),
            activation="tanh",
            solver="lbfgs",
            alpha=1.0,
            max_iter=4000,
            random_state=seed,
        )),
    ])
    return TransformedTargetRegressor(
        regressor=network, transformer=StandardScaler()
    )

print("FEMM training samples:", len(X_dnn))
print("DNN inputs:", factors)
print("DNN outputs:", dnn_targets)
"""
    ),
    md("## 8.1 반복 교차검증"),
    code(
        """
cv = RepeatedKFold(n_splits=5, n_repeats=5, random_state=20260731)
pred_sum = np.zeros_like(y_dnn)
pred_count = np.zeros(len(y_dnn), dtype=int)

for fold, (train_idx, test_idx) in enumerate(cv.split(X_dnn)):
    model = make_dnn(1000 + fold)
    model.fit(X_dnn[train_idx], y_dnn[train_idx])
    pred_sum[test_idx] += model.predict(X_dnn[test_idx])
    pred_count[test_idx] += 1

dnn_cv_pred = pred_sum / pred_count[:, None]
dnn_metrics = pd.DataFrame({
    "Repeated-CV R2": [
        r2_score(y_dnn[:, j], dnn_cv_pred[:, j]) for j in range(2)
    ],
    "Repeated-CV RMSE": [
        root_mean_squared_error(y_dnn[:, j], dnn_cv_pred[:, j])
        for j in range(2)
    ],
}, index=["Mean torque [Nm]", "Ripple pk-pk [Nm]"])
display(dnn_metrics)

fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))
for j, title in enumerate(["Mean torque", "Torque ripple pk-pk"]):
    axes[j].scatter(y_dnn[:, j], dnn_cv_pred[:, j], s=45, alpha=0.75)
    lo = min(y_dnn[:, j].min(), dnn_cv_pred[:, j].min())
    hi = max(y_dnn[:, j].max(), dnn_cv_pred[:, j].max())
    axes[j].plot([lo, hi], [lo, hi], "--", color="0.25")
    axes[j].set(
        xlabel="FEMM [Nm]", ylabel="Repeated-CV prediction [Nm]",
        title=title,
    )
plt.tight_layout()
plt.show()
"""
    ),
    md(
        """
교차검증 성능이 낮으면 10,000점을 생성해도 해상도만 높아질 뿐 정확도가 높아지는 것은 아니다.
따라서 파레토 후보의 앙상블 표준편차와 FEMM 재검증을 반드시 함께 사용한다.
"""
    ),
    md("## 8.2 형상검사 통과 LHS 후보 10,000점"),
    code(
        """
n_candidates = 10_000
names = list(RANGES)
lower = np.array([RANGES[name][0] for name in names])
upper = np.array([RANGES[name][1] for name in names])
sampler = qmc.LatinHypercube(
    d=len(names), seed=20260731, optimization="random-cd"
)

candidate_cache = ROOT / "double_layer_dnn_candidates_10000.csv"
if candidate_cache.exists() and len(pd.read_csv(candidate_cache)) == n_candidates:
    candidates = pd.read_csv(candidate_cache)
    print(f"Loaded {len(candidates):,} cached geometry-valid candidates")
else:
    valid_rows = []
    tested = 0
    while len(valid_rows) < n_candidates:
        unit = sampler.random(12_000)
        batch = qmc.scale(unit, lower, upper)
        for values in batch:
            tested += 1
            row = evaluate(
                tested,
                {name: float(value) for name, value in zip(names, values)},
            )
            if row["geometry_status"] == "OK":
                valid_rows.append(row)
                if len(valid_rows) == n_candidates:
                    break
    candidates = pd.DataFrame(valid_rows)
    candidates["candidate"] = np.arange(1, len(candidates) + 1)
    print(f"Generated {tested:,} points; accepted {len(candidates):,}")
display(candidates[factors + [
    "outer_bridge_min_mm", "shaft_clearance_min_mm",
    "other_magnet_gap_min_mm"
]].describe().T)
"""
    ),
    md("## 8.3 DNN 30개 앙상블 예측"),
    code(
        """
n_ensemble = 30
candidate_X = candidates[factors].to_numpy(dtype=float)
ensemble = []
for seed in range(n_ensemble):
    model = make_dnn(2000 + seed)
    model.fit(X_dnn, y_dnn)
    ensemble.append(model.predict(candidate_X))

ensemble = np.stack(ensemble)
prediction = ensemble.mean(axis=0)
ensemble_std = ensemble.std(axis=0, ddof=1)
# Initialisation spread alone is too optimistic. Combine it with the
# out-of-fold residual scale measured above.
cv_rmse = dnn_metrics["Repeated-CV RMSE"].to_numpy(dtype=float)
uncertainty = np.sqrt(ensemble_std**2 + cv_rmse[None, :]**2)

candidates["pred_mean_torque_Nm"] = prediction[:, 0]
candidates["pred_ripple_pkpk_Nm"] = prediction[:, 1]
candidates["unc_mean_torque_Nm"] = uncertainty[:, 0]
candidates["unc_ripple_pkpk_Nm"] = uncertainty[:, 1]
candidates["ensemble_std_mean_torque_Nm"] = ensemble_std[:, 0]
candidates["ensemble_std_ripple_pkpk_Nm"] = ensemble_std[:, 1]
candidates["conservative_mean_Nm"] = (
    candidates.pred_mean_torque_Nm - candidates.unc_mean_torque_Nm
)
candidates["conservative_ripple_Nm"] = (
    candidates.pred_ripple_pkpk_Nm + candidates.unc_ripple_pkpk_Nm
)

def fast_pareto(frame, mean_name, ripple_name):
    ordered = frame.sort_values(
        [mean_name, ripple_name], ascending=[False, True]
    )
    best_ripple = np.inf
    selected = []
    for idx, row in ordered.iterrows():
        if row[ripple_name] < best_ripple:
            selected.append(idx)
            best_ripple = row[ripple_name]
    mask = pd.Series(False, index=frame.index)
    mask.loc[selected] = True
    return mask

candidates["predicted_pareto"] = fast_pareto(
    candidates, "pred_mean_torque_Nm", "pred_ripple_pkpk_Nm"
)
candidates["conservative_pareto"] = fast_pareto(
    candidates, "conservative_mean_Nm", "conservative_ripple_Nm"
)
pred_front = candidates[candidates.predicted_pareto].copy()
print("Predicted Pareto:", len(pred_front))
print("Conservative Pareto:", int(candidates.conservative_pareto.sum()))
"""
    ),
    md("## 8.4 촘촘한 예측 파레토"),
    code(
        """
front_sorted = pred_front.sort_values("pred_mean_torque_Nm")
fig, ax = plt.subplots(figsize=(10, 6.5))
ax.scatter(
    candidates.pred_mean_torque_Nm,
    candidates.pred_ripple_pkpk_Nm,
    s=8, alpha=0.10, label="10,000 DNN candidates",
)
ax.plot(
    front_sorted.pred_mean_torque_Nm,
    front_sorted.pred_ripple_pkpk_Nm,
    "-o", color="crimson", lw=2, ms=3, label="Predicted Pareto",
)
ax.scatter(
    df[mean_col], df[ripple_col],
    marker="x", color="black", s=55, label="50 FEMM points",
)
ax.set(
    xlabel="Mean torque [Nm]",
    ylabel="Ripple pk-pk [Nm]",
    title="Double-layer DNN surrogate: 10,000 candidates",
)
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md("## 8.5 균형 최적점과 FEMM 재검증 후보"),
    code(
        """
# 파레토 내부에서 ideal point까지 정규화 거리
torque_span = (
    pred_front.pred_mean_torque_Nm.max()
    - pred_front.pred_mean_torque_Nm.min()
)
ripple_span = (
    pred_front.pred_ripple_pkpk_Nm.max()
    - pred_front.pred_ripple_pkpk_Nm.min()
)
pred_front["torque_loss_norm"] = (
    pred_front.pred_mean_torque_Nm.max()
    - pred_front.pred_mean_torque_Nm
) / torque_span
pred_front["ripple_loss_norm"] = (
    pred_front.pred_ripple_pkpk_Nm
    - pred_front.pred_ripple_pkpk_Nm.min()
) / ripple_span
pred_front["ideal_distance"] = np.hypot(
    pred_front.torque_loss_norm, pred_front.ripple_loss_norm
)

# FEMM 검증 후보: knee 3개 + 저리플 끝점 + 고토크 끝점
knee = pred_front.nsmallest(3, "ideal_distance")
low_ripple = pred_front.nsmallest(1, "pred_ripple_pkpk_Nm")
high_torque = pred_front.nlargest(1, "pred_mean_torque_Nm")
validation = (
    pd.concat([knee, low_ripple, high_torque])
    .drop_duplicates("candidate")
    .sort_values("ideal_distance")
)

result_cols = [
    "candidate", *factors, "magnet_center_offset_deg",
    "outer_bridge_min_mm", "other_magnet_gap_min_mm",
    "pred_mean_torque_Nm", "unc_mean_torque_Nm",
    "pred_ripple_pkpk_Nm", "unc_ripple_pkpk_Nm",
    "conservative_mean_Nm", "conservative_ripple_Nm",
    "ideal_distance",
]
print("FEMM 재검증 우선 후보")
display(validation[result_cols].set_index("candidate"))
"""
    ),
    md("## 8.6 예측 결과 저장"),
    code(
        """
candidate_csv = ROOT / "double_layer_dnn_candidates_10000.csv"
pareto_csv = ROOT / "double_layer_dnn_predicted_pareto.csv"
validation_csv = ROOT / "double_layer_dnn_femm_validation_candidates.csv"

candidates.to_csv(candidate_csv, index=False)
pred_front.sort_values("ideal_distance").to_csv(pareto_csv, index=False)
validation[result_cols].to_csv(validation_csv, index=False)

print("Saved:", candidate_csv)
print("Saved:", pareto_csv)
print("Saved:", validation_csv)
"""
    ),
    md(
        """
## 9. 이 분석에서 말하는 최적점

- 50개 FEMM 파레토는 **관측된 최선점**
- 10,000개 DNN 파레토는 **surrogate가 제안한 최적 후보**
- 최종 최적점은 **DNN 후보를 FEMM으로 재해석한 뒤** 확정

따라서 다음 단계는 `double_layer_dnn_femm_validation_candidates.csv`의 후보를
0–30°, 0.5° 간격과 commutation offset 재탐색 조건으로 FEMM 검증하는 것이다.
검증 결과를 기존 50점에 추가해 DNN을 재학습하면 순차적으로 최적점 신뢰도가 높아진다.
"""
    ),
])

nbformat.write(nb, NOTEBOOK)
print(f"Updated: {NOTEBOOK}")
