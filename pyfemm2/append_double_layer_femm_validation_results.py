from pathlib import Path

import nbformat


ROOT = Path(__file__).resolve().parent
NOTEBOOK = ROOT / "double_layer_ccf_55to90_dnn_analysis.ipynb"
TAG = "actual-femm-validation-results"


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
# 14. DNN 후보 5개 실제 FEMM 검증 결과

앞에서 선정한 5개 후보를 DNN 학습조건과 동일한 조건으로 재해석했다.

- 회전자 각도: 0–28°, 2° 간격
- 전류 피크: 10 A
- commutation offset: 35°
- 각 후보당 15개 운전점

아래 값은 DNN 예측이 아니라 실제 FEMM 결과다.
"""
    ),
    code(
        """
VALIDATION_DIR = ROOT / "double_layer_55to90_femm_validation_5" / "results"
validation_femm = pd.read_csv(
    VALIDATION_DIR / "double_layer_ccf_summary.csv"
)
validation_femm["mean_error_Nm"] = (
    validation_femm.loaded_torque_mean_Nm
    - validation_femm.pred_mean_torque_Nm
)
validation_femm["mean_error_pct"] = (
    100 * validation_femm.mean_error_Nm
    / validation_femm.pred_mean_torque_Nm
)
validation_femm["ripple_error_Nm"] = (
    validation_femm.loaded_torque_pkpk_Nm
    - validation_femm.pred_ripple_pkpk_Nm
)
validation_femm["ripple_error_pct"] = (
    100 * validation_femm.ripple_error_Nm
    / validation_femm.pred_ripple_pkpk_Nm
)

validation_display = [
    "candidate", "selection_purpose",
    "pred_mean_torque_Nm", "loaded_torque_mean_Nm",
    "mean_error_Nm", "mean_error_pct",
    "pred_ripple_pkpk_Nm", "loaded_torque_pkpk_Nm",
    "ripple_error_Nm", "ripple_error_pct",
    "magnet_volume_total_cm3",
]
display(validation_femm[validation_display].set_index("candidate"))
"""
    ),
    md("## 14.1 DNN 예측 정확도"),
    code(
        """
validation_metrics = pd.DataFrame({
    "MAE [Nm]": [
        validation_femm.mean_error_Nm.abs().mean(),
        validation_femm.ripple_error_Nm.abs().mean(),
    ],
    "RMSE [Nm]": [
        np.sqrt(np.mean(validation_femm.mean_error_Nm**2)),
        np.sqrt(np.mean(validation_femm.ripple_error_Nm**2)),
    ],
    "Maximum absolute error [Nm]": [
        validation_femm.mean_error_Nm.abs().max(),
        validation_femm.ripple_error_Nm.abs().max(),
    ],
}, index=["Mean torque", "Ripple pk-pk"])
display(validation_metrics)

fig, axes = plt.subplots(1, 2, figsize=(13, 5.5))
for ax, pred_col, femm_col, title in [
    (
        axes[0], "pred_mean_torque_Nm", "loaded_torque_mean_Nm",
        "Mean torque: DNN vs FEMM",
    ),
    (
        axes[1], "pred_ripple_pkpk_Nm", "loaded_torque_pkpk_Nm",
        "Ripple: DNN vs FEMM",
    ),
]:
    ax.scatter(
        validation_femm[pred_col], validation_femm[femm_col],
        s=70,
    )
    for _, row in validation_femm.iterrows():
        ax.annotate(
            f"C{int(row.candidate)}",
            (row[pred_col], row[femm_col]),
            xytext=(4, 5), textcoords="offset points",
        )
    lo = min(validation_femm[pred_col].min(), validation_femm[femm_col].min())
    hi = max(validation_femm[pred_col].max(), validation_femm[femm_col].max())
    ax.plot([lo, hi], [lo, hi], "--", color="0.25")
    ax.set(xlabel="DNN prediction [Nm]", ylabel="FEMM [Nm]", title=title)
plt.tight_layout()
plt.show()
"""
    ),
    md("## 14.2 실제 토크 파형"),
    code(
        """
fig, ax = plt.subplots(figsize=(10, 6))
for _, row in validation_femm.iterrows():
    run = int(row.run)
    candidate = int(row.candidate)
    sweep = pd.read_csv(
        VALIDATION_DIR / f"run_{run:03d}"
        / "axis_shortedge_loaded_sweep.csv"
    )
    ax.plot(
        sweep.theta_deg, sweep.torque_Nm,
        "-o", ms=4, label=f"C{candidate}: {row.selection_purpose}",
    )
ax.set(
    xlabel="Mechanical angle [deg]",
    ylabel="FEMM torque [Nm]",
    title="Actual FEMM torque waveforms of five DNN candidates",
)
ax.legend(fontsize=8)
plt.tight_layout()
plt.show()
"""
    ),
    md("## 14.3 싱글레이어 기준점과 실제 FEMM 비교"),
    code(
        """
single_reference = single50[single50.run.isin([14, 49, 42, 27])].copy()
single_reference["design"] = "Single Run " + single_reference.run.astype(str)
single_reference["magnet_volume_total_cm3"] = (
    8
    * single_reference.magnet_thickness_mm
    * single_reference.magnet_length_mm
    * motor_base.DEPTH / 1000
)
single_compare = single_reference[[
    "design", "magnet_volume_total_cm3",
    mean_col, ripple_col,
]].rename(columns={
    mean_col: "mean_torque_Nm",
    ripple_col: "ripple_pkpk_Nm",
})

double_compare = validation_femm.copy()
double_compare["design"] = (
    "Double C" + double_compare.candidate.astype(int).astype(str)
)
double_compare = double_compare[[
    "design", "magnet_volume_total_cm3",
    "loaded_torque_mean_Nm", "loaded_torque_pkpk_Nm",
]].rename(columns={
    "loaded_torque_mean_Nm": "mean_torque_Nm",
    "loaded_torque_pkpk_Nm": "ripple_pkpk_Nm",
})
actual_comparison = pd.concat(
    [single_compare, double_compare], ignore_index=True
)
actual_comparison["torque_per_magnet_Nm_cm3"] = (
    actual_comparison.mean_torque_Nm
    / actual_comparison.magnet_volume_total_cm3
)
display(actual_comparison.set_index("design"))

fig, ax = plt.subplots(figsize=(10, 6))
for layer, marker in [("Single", "o"), ("Double", "s")]:
    part = actual_comparison[
        actual_comparison.design.str.startswith(layer)
    ]
    ax.scatter(
        part.magnet_volume_total_cm3,
        part.mean_torque_Nm,
        s=70, marker=marker, label=layer,
    )
    for _, row in part.iterrows():
        ax.annotate(
            row.design,
            (row.magnet_volume_total_cm3, row.mean_torque_Nm),
            xytext=(4, 4), textcoords="offset points",
        )
ax.set(
    xlabel="Total magnet volume [cm³]",
    ylabel="Actual FEMM mean torque [Nm]",
    title="Actual FEMM: magnet usage vs mean torque",
)
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md(
        """
## 14.4 최종 평가

### Candidate 6038 — 더블레이어 최대토크 우위 확인

- FEMM 평균토크: **53.45 Nm**
- FEMM 리플: **10.09 Nm**
- 자석 체적: **90.13 cm³**
- 싱글레이어 최대 Run 27보다 자석을 약 9% 적게 사용하면서 평균토크는 약 4.7% 높고 리플은 약간 작다.
- 현재 검증점 중 더블레이어의 가장 명확한 성능 우위다.

### Candidate 4325 — 자석 절감 효과 확인

- FEMM 평균토크: **46.21 Nm**
- FEMM 리플: **8.48 Nm**
- 자석 체적: **58.98 cm³**
- 싱글레이어 Run 49와 비슷한 평균토크를 자석 약 36% 절감으로 달성했지만 리플이 약 81% 크다.
- 자석비용 최소화가 중요할 때 유효하고 저리플 설계로는 부적합하다.

### Candidate 5983 — 가장 좋은 실용 균형점

- FEMM 평균토크: **47.67 Nm**
- FEMM 리플: **5.10 Nm**
- 자석 체적: **88.49 cm³**
- 싱글레이어 Run 42보다 평균토크는 약 0.6% 낮고 리플은 약 0.9% 작다.
- 싱글레이어 Run 49보다는 자석을 약 4.6% 줄이고 평균토크를 약 2.0% 높이지만 리플은 약 8.6% 크다.
- 토크·리플·자석량을 함께 볼 때 현재 더블레이어의 가장 실용적인 후보로 판단한다.

### Candidate 4791 — Candidate 5983에 근접

- FEMM 평균토크: **47.47 Nm**
- FEMM 리플: **5.42 Nm**
- 자석 체적: **87.04 cm³**
- Candidate 5983보다 자석은 약 1.6% 적지만 토크와 리플이 모두 조금 불리하다.

### Candidate 9439 — 저리플 우위 미확인

- FEMM 평균토크: **37.15 Nm**
- FEMM 리플: **2.96 Nm**
- 자석 체적: **58.83 cm³**
- 싱글레이어 저리플 Run 14보다 리플은 조금 작지만 토크가 약 3.9% 낮고 자석은 약 6% 많다.
- 저리플 영역에서는 더블레이어의 명확한 이점이 없다.

## 다음 정밀검증 권장

Candidate **6038, 5983, 4325** 세 개를 남긴다.

1. 0–30° / 0.5° 간격 토크 스윕
2. commutation offset 30–40° 재탐색
3. 코깅토크와 무부하 역기전력 THD
4. 최대 반경력 및 브리지 포화 확인

Candidate 4791과 9439는 현재 결과에서는 추가 정밀해석 우선순위가 낮다.
"""
    ),
])

nbformat.write(nb, NOTEBOOK)
print(f"Updated: {NOTEBOOK}")
