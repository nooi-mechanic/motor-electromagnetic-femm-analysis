# Airgap Sensitivity Report

기준 조건:

- 4극 권선
- 전류 `10 A`
- 전기각 오프셋 `60 deg`
- airgap sweep: `0.5, 0.6, 0.7, 0.8, 0.9 mm`

## Summary

이번 airgap sensitivity 결과에서는 airgap이 증가할수록 평균 토크가 거의 선형적으로 감소했다. 반면 코깅토크 peak-to-peak는 증가했고, 토크리플은 큰 변화 없이 비슷한 수준을 유지했다. 최대 radial force는 전체적으로 큰 변화는 아니지만 `0.6 mm` 부근에서 가장 낮게 나타났다.

핵심 해석은 다음과 같다.

- `airgap 증가 -> 공극 자기저항 증가 -> 자속 감소 -> 평균 토크 감소`
- 현재 `0.5 ~ 0.9 mm` 범위에서는 평균 토크 감소가 거의 직선 관계로 나타났다
- 코깅토크는 airgap 증가에 따라 악화되는 방향을 보였다
- 평균토크 기준으로는 작은 airgap이 유리했고, force_max만 보면 `0.6 mm` 부근이 상대적으로 유리했다

## Plot

![Airgap sensitivity summary plot](../airgap_sensitivity_summary_plot.png)

## Data Table

| Airgap (mm) | Mean Torque (N.m) | Torque Ripple (%) | Cogging P-P (N.m) | Max Radial Force (N) | Mean Radial Force (N) |
|---|---:|---:|---:|---:|---:|
| 0.5 | 37.0750 | 22.0473 | 0.00430 | 1054.17 | 713.99 |
| 0.6 | 36.5782 | 21.7017 | 0.00856 | 1029.28 | 742.78 |
| 0.7 | 36.1318 | 21.6483 | 0.01313 | 1034.23 | 777.88 |
| 0.8 | 35.5929 | 21.5942 | 0.01956 | 1048.26 | 812.42 |
| 0.9 | 35.0668 | 21.5968 | 0.02293 | 1065.07 | 846.28 |

원본 데이터:

- [airgap_sensitivity_summary.csv](/Users/dohyunkim/Documents/Window/airgap_sensitivity_summary.csv)
- [airgap_sensitivity_result.mat](/Users/dohyunkim/Documents/Window/airgap_sensitivity_result.mat)

## Trend Interpretation

### 1. Mean Torque

평균 토크는 airgap이 커질수록 감소했다. 1차 적합 결과는

$$
T_{\mathrm{mean}} \approx 39.5902 - 5.0017 \, g(\mathrm{mm})
$$

이며,

$$
R^2 = 0.99894
$$

로 매우 높은 직선성을 보였다. 따라서 현재 범위에서는 airgap 증가에 따른 평균 토크 감소를 거의 선형으로 보아도 무방하다.

정량적으로는 airgap이 `0.1 mm` 증가할 때 평균 토크가 약 `0.50 N.m` 감소하는 수준이다.

### 2. Torque Ripple

토크리플은 약 `21.6 ~ 22.0 %` 범위에 머물렀다. 즉 이번 범위에서는 airgap 변화가 평균 토크에는 명확한 영향을 주었지만, 토크리플에는 상대적으로 약한 영향을 준 것으로 보인다.

### 3. Cogging Torque

코깅토크 peak-to-peak는 airgap 증가와 함께 증가했다. 특히 `0.5 mm`에서 `0.00430 N.m`였던 값이 `0.9 mm`에서 `0.02293 N.m`까지 커졌다. 따라서 공극을 키우는 방향은 평균 토크 감소뿐 아니라 코깅 성능에도 불리하게 작용했다.

### 4. Radial Force

최대 radial force는 `1029 ~ 1065 N` 수준으로 나타났다. 최솟값은 `0.6 mm`에서 나왔지만 변화 폭이 아주 크지는 않다. 반면 평균 radial force는 airgap 증가와 함께 증가했다.

## Sensitivity

문서 정의대로 `g0 = 0.5 mm` 기준, `0.5 -> 0.6 mm` 전진차분으로 계산한 민감도는 다음과 같다.

| Output | Absolute Sensitivity | Normalized Sensitivity S | Interpretation |
|---|---:|---:|---|
| Mean torque | `-4.968 N.m/mm` | `-0.0670` | airgap 1% 증가 시 평균토크 약 0.067% 감소 |
| Torque ripple | `-3.456 %/mm` | `-0.0784` | airgap 1% 증가 시 토크리플 약 0.078% 감소 |
| Cogging torque p-p | `+0.0426 N.m/mm` | `+4.955` | airgap 1% 증가 시 코깅토크 약 4.96% 증가 |
| Max radial force | `-248.89 N/mm` | `-0.118` | airgap 1% 증가 시 최대 radial force 약 0.118% 감소 |
| Mean radial force | `+287.87 N/mm` | `+0.202` | airgap 1% 증가 시 평균 radial force 약 0.202% 증가 |

## Design Implication

현재 결과만 놓고 보면:

- 평균 토크를 가장 우선하면 `0.5 mm`가 가장 유리하다
- 최대 radial force만 보면 `0.6 mm`가 가장 낮다
- 코깅토크까지 함께 고려하면 작은 airgap 쪽이 더 유리하다

따라서 이번 범위에서는 `airgap을 무작정 키우는 방향`은 타당하지 않다. 다음 단계 최적화에서는 airgap을 일단 고정하거나 좁은 범위로만 두고, `magnet thickness`, `magnet length`, `V-angle` 같은 형상변수와의 상호작용을 보는 것이 더 합리적이다.
