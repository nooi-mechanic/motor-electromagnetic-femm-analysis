from pathlib import Path

import nbformat


ROOT = Path(__file__).resolve().parent
NOTEBOOK = ROOT / "double_layer_ccf_50_analysis.ipynb"
TAG = "magnet-usage-torque-pareto"


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
# 10. 자석 사용량 최소화–평균토크 최대화 파레토

이번 파레토의 목적함수는 다음 두 개다.

- **회전자 전체 자석 사용량 최소화**
- **DNN 예측 평균토크 최대화**

안쪽 자석 한 장의 두께는 총 두께의 1/2이고, 바깥 자석은 안쪽 대비 길이와 두께가 각각 80%다.
따라서 한쪽 V-wing의 자석 단면적은 다음과 같다.

\\[
A_{wing} =
\\frac{T}{2}L +
\\left(0.8\\frac{T}{2}\\right)(0.8L)
=0.82TL
\\]

4극 × 좌우 2개 wing이므로 회전자 전체 자석 단면적은 \(8\\times0.82TL\)이다.
모델 적층 길이를 곱해 자석 체적도 함께 계산한다.
"""
    ),
    code(
        """
import generate_v_ipm_motor as motor_base

MAGNET_FACTOR = 8 * (0.5 + 0.5 * 0.8 * 0.8)
candidates["magnet_area_total_mm2"] = (
    MAGNET_FACTOR
    * candidates["total_thickness_mm"]
    * candidates["inner_length_mm"]
)
candidates["magnet_volume_total_cm3"] = (
    candidates["magnet_area_total_mm2"] * motor_base.DEPTH / 1000
)
candidates["pred_torque_per_magnet_cm3"] = (
    candidates["pred_mean_torque_Nm"]
    / candidates["magnet_volume_total_cm3"]
)

def magnet_torque_pareto(frame):
    # Torque descending: retain each new record-low magnet volume.
    ordered = frame.sort_values(
        ["pred_mean_torque_Nm", "magnet_volume_total_cm3"],
        ascending=[False, True],
    )
    best_volume = np.inf
    selected = []
    for idx, row in ordered.iterrows():
        if row["magnet_volume_total_cm3"] < best_volume:
            selected.append(idx)
            best_volume = row["magnet_volume_total_cm3"]
    mask = pd.Series(False, index=frame.index)
    mask.loc[selected] = True
    return mask

candidates["magnet_torque_pareto"] = magnet_torque_pareto(candidates)
magnet_front = candidates[candidates.magnet_torque_pareto].copy()
magnet_front = magnet_front.sort_values("magnet_volume_total_cm3")
print(f"Magnet–torque Pareto designs: {len(magnet_front)} / {len(candidates)}")
print(f"Motor stack depth: {motor_base.DEPTH:g} mm")
"""
    ),
    md("## 10.1 자석 체적–평균토크 파레토"),
    code(
        """
fig, ax = plt.subplots(figsize=(10, 6.5))
scatter = ax.scatter(
    candidates["magnet_volume_total_cm3"],
    candidates["pred_mean_torque_Nm"],
    c=candidates["pred_ripple_pkpk_Nm"],
    cmap="viridis", s=9, alpha=0.18,
)
ax.plot(
    magnet_front["magnet_volume_total_cm3"],
    magnet_front["pred_mean_torque_Nm"],
    "-o", color="crimson", lw=2, ms=3,
    label="Magnet–torque Pareto",
)
ax.set(
    xlabel="Total magnet volume [cm³]",
    ylabel="Predicted mean torque [Nm]",
    title="Minimum magnet usage vs maximum mean torque",
)
fig.colorbar(scatter, ax=ax, label="Predicted ripple pk-pk [Nm]")
ax.legend()
plt.tight_layout()
plt.show()
"""
    ),
    md(
        """
색은 예측 절대 리플이다. 자석–토크 파레토에 포함되더라도 리플이 지나치게 크면 실제 추천 후보에서는 제외할 수 있다.
"""
    ),
    md("## 10.2 균형점과 FEMM 검증 후보"),
    code(
        """
volume_span = (
    magnet_front.magnet_volume_total_cm3.max()
    - magnet_front.magnet_volume_total_cm3.min()
)
torque_span = (
    magnet_front.pred_mean_torque_Nm.max()
    - magnet_front.pred_mean_torque_Nm.min()
)
magnet_front["volume_loss_norm"] = (
    magnet_front.magnet_volume_total_cm3
    - magnet_front.magnet_volume_total_cm3.min()
) / volume_span
magnet_front["torque_loss_norm"] = (
    magnet_front.pred_mean_torque_Nm.max()
    - magnet_front.pred_mean_torque_Nm
) / torque_span
magnet_front["magnet_torque_ideal_distance"] = np.hypot(
    magnet_front.volume_loss_norm,
    magnet_front.torque_loss_norm,
)

# 기본 knee 후보와 리플 6 Nm 이하인 실용 후보를 각각 확인한다.
magnet_knee = magnet_front.nsmallest(10, "magnet_torque_ideal_distance")
practical_front = magnet_front[
    magnet_front.pred_ripple_pkpk_Nm <= 6.0
].copy()
practical_knee = practical_front.nsmallest(
    10, "magnet_torque_ideal_distance"
)

magnet_cols = [
    "candidate", *factors,
    "magnet_volume_total_cm3",
    "pred_mean_torque_Nm", "unc_mean_torque_Nm",
    "pred_ripple_pkpk_Nm", "unc_ripple_pkpk_Nm",
    "pred_torque_per_magnet_cm3",
    "magnet_torque_ideal_distance",
]
print("자석량–토크 순수 파레토 균형 후보")
display(magnet_knee[magnet_cols].set_index("candidate"))
print("리플 6 Nm 이하 조건을 만족하는 균형 후보")
display(practical_knee[magnet_cols].set_index("candidate"))
"""
    ),
    md("## 10.3 결과 저장"),
    code(
        """
magnet_front_csv = ROOT / "double_layer_dnn_magnet_torque_pareto.csv"
magnet_validation_csv = (
    ROOT / "double_layer_dnn_magnet_torque_validation_candidates.csv"
)
magnet_front.sort_values(
    "magnet_torque_ideal_distance"
).to_csv(magnet_front_csv, index=False)
practical_knee[magnet_cols].to_csv(magnet_validation_csv, index=False)
print("Saved:", magnet_front_csv)
print("Saved:", magnet_validation_csv)
"""
    ),
    md(
        """
## 10.4 해석 기준

- 순수 파레토는 자석량과 평균토크만 판단하므로 리플이 큰 고토크 형상도 포함된다.
- 실제 FEMM 검증 우선순위는 `리플 6 Nm 이하` 표의 상위 후보가 더 적절하다.
- 최종 경제성 비교에는 자석 체적뿐 아니라 철손, 역기전력, 감자 여유와 기계적 브리지 강도도 추가해야 한다.
"""
    ),
])

nbformat.write(nb, NOTEBOOK)
print(f"Updated: {NOTEBOOK}")
