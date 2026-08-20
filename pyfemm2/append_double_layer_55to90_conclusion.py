from pathlib import Path

import nbformat


ROOT = Path(__file__).resolve().parent
NOTEBOOK = ROOT / "double_layer_ccf_55to90_dnn_analysis.ipynb"
TAG = "final-assessment-before-femm-validation"

nb = nbformat.read(NOTEBOOK, as_version=4)
nb.cells = [
    cell for cell in nb.cells
    if TAG not in cell.get("metadata", {}).get("tags", [])
]

cell = nbformat.v4.new_markdown_cell(
    """
# 13. 결과 평가와 실제 FEMM 검증 후보

V각 범위를 55°까지 확장하자 최적점이 55° 경계로 내려가지 않고 목적에 따라 내부 영역으로 분리됐다.

- 최대토크 영역: 약 63°
- 자석량 대비 토크 영역: 약 63–69°
- 토크–리플 균형 영역: 약 79–82°
- 리플 최소 영역: 약 87–89°

따라서 기존 70–90° DOE에서 후보가 70° 하한에 몰린 것은 실제 최적각이 70°라서가 아니라 설계범위가 좁았기 때문이다.
GitHub의 기존 싱글레이어 분석에서 나타난 60° 부근 최적 경향과 이번 더블레이어 최대토크 영역이 연결된다.

## 싱글레이어 대비 평가

- Candidate 6038은 싱글레이어 최대토크 Run 27보다 자석을 약 9% 적게 사용하면서 평균토크가 약 2% 높을 것으로 예측됐다. 리플은 비슷하다.
- Candidate 4325는 싱글레이어 Run 49와 비슷한 평균토크를 예측하면서 자석 사용량을 약 36% 줄이지만 리플이 크다.
- Candidate 5983과 4791은 자석을 약 5–6% 줄이고 평균토크를 유지하지만 싱글레이어 Run 49보다 리플이 약 1 Nm 크다.
- Candidate 9439는 싱글레이어 저리플 Run 14와 성능이 비슷해 더블레이어의 명확한 우위는 아직 확인되지 않았다.

## 실제 FEMM 검증 대상

| 우선순위 | Candidate | 목적 | DNN 예측 평균토크 | DNN 예측 리플 |
|---:|---:|---|---:|---:|
| 1 | 6038 | 최대토크 | 52.24 Nm | 10.53 Nm |
| 2 | 4325 | 자석 절감·토크 효율 | 46.68 Nm | 8.24 Nm |
| 3 | 5983 | 토크–리플 균형 | 46.97 Nm | 5.64 Nm |
| 4 | 4791 | 균형 대안 | 47.08 Nm | 5.76 Nm |
| 5 | 9439 | 리플 최소 | 38.75 Nm | 2.83 Nm |

이 다섯 점은 우선 DNN 학습 데이터와 동일한 `0–28° / 2°`, 전류 10 A, commutation offset 35° 조건으로 FEMM 검증한다.
검증 오차가 허용 범위이면 유망 후보만 `0–30° / 0.5°` 및 commutation offset 재탐색으로 정밀 검증한다.
""".strip()
)
cell.metadata["tags"] = [TAG]
nb.cells.append(cell)
nbformat.write(nb, NOTEBOOK)
print(f"Updated: {NOTEBOOK}")
