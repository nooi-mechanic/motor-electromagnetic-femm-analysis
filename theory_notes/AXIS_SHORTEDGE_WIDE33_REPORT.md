# Axis-Shortedge Wide33 Report

최종 갱신: 2026-07-23

이번 리포트는 `wide_add33` 해석 결과를 기존 `15점`과 합쳐서 읽은 것이다.

데이터 구성은 다음과 같다.

- 기존 범위 DOE: `15점`
- 확장 범위 DOE: `33점`
- 합산: `48점`

핵심 질문은 세 가지다.

1. 범위를 넓히면 평균 토크-토크 리플의 trade-off가 새롭게 나타나는가
2. 기존 최고점 `run 8`이 여전히 강한가
3. 코깅과 force까지 같이 보면 어떤 후보가 현실적인가

## 1. 먼저 결론

짧게 말하면 다음과 같다.

- `wide 33점`을 추가해도 평균 토크와 토크 리플은 여전히 강한 역상관을 보인다
- 즉 현재 탐색 범위에서는 `토크 증가`와 `리플 감소`가 아직 꽤 같은 방향으로 움직인다
- 따라서 기대했던 의미의 `길게 펼쳐진 Pareto front`는 여전히 약하다
- 다만 기존 `run 8`과 매우 가까운 성능의 새로운 이웃점 `run 121`이 나타나서, 좋은 구간이 단일 우연점은 아니라는 점은 확인되었다

수치적으로 보면:

- 기존 15점 상관계수: `corr(Tavg, ripple) = -0.848`
- wide 33점 상관계수: `corr(Tavg, ripple) = -0.828`
- 합산 48점 상관계수: `corr(Tavg, ripple) = -0.834`

즉 범위를 넓혀도 아직은

```text
더 큰 평균 토크  ->  더 작은 토크 리플
```

경향이 유지되고 있다.

## 2. 전체 분포

아래 그림은 기존 15점과 wide 33점을 함께 그린 것이다.

![Torque Ripple Scatter](/Users/dohyunkim/Documents/Window/femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add33/wide33_vs_old15_torque_ripple.png)

이 그림에서 보이는 핵심은 다음과 같다.

- 기존 `run 8`이 여전히 가장 높은 평균 토크를 가진다
- 그러나 `run 121`이 그 바로 아래에서 더 낮은 리플을 보인다
- 합산 48점 기준 Pareto envelope은 사실상 `run 8`과 `run 121` 두 점만 남는다

즉 이번 wide run은 완전히 새로운 trade-off front를 만든 것이 아니라,
기존 최적 부근에 `근접한 이웃점`이 존재함을 보여준 쪽에 가깝다.

## 3. 다른 출력과 함께 보면

아래 그림은 평균 토크를 기준으로 리플, 코깅, force, V-angle 관계를 함께 본 것이다.

![Tradeoff Matrix](/Users/dohyunkim/Documents/Window/femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add33/wide33_tradeoff_matrix.png)

이 그림에서 읽을 수 있는 점은 다음과 같다.

- `평균 토크`와 `토크 리플`은 현재 범위 안에서 여전히 반비례 경향이 강하다
- `평균 토크`가 높은 점들은 force도 함께 낮아지는 경향이 있다
- 하지만 최고 토크권에서는 `cogging torque`가 다시 커지는 문제가 남아 있다

즉 현재 문제는

```text
torque vs ripple
```

보다 오히려

```text
high torque, low ripple
vs
high cogging
```

쪽이 더 실제적인 충돌축으로 보인다.

## 4. 대표 후보 해석

### 4-1. 최고 토크 후보

- `run 8`
  - thickness = `5.0 mm`
  - length = `16.0 mm`
  - v_angle = `60.0 deg`
  - average torque = `50.73 N.m`
  - torque ripple = `22.09 %`
  - cogging torque p-p = `0.3782 N.m`
  - max force = `841 N`

이 점은 여전히 전체 최고 토크다.

### 4-2. 저리플-고토크 이웃 후보

- `run 121`
  - thickness = `4.857 mm`
  - length = `16.463 mm`
  - v_angle = `55.31 deg`
  - average torque = `48.99 N.m`
  - torque ripple = `21.66 %`
  - cogging torque p-p = `0.3790 N.m`
  - max force = `839 N`

이 점은 `run 8`보다 토크는 약간 낮지만 리플은 더 낮다.  
하지만 코깅은 거의 동일하게 높다.

즉 `run 121`은 `run 8`을 완전히 대체한다기보다, `run 8` 주변의 좋은 형상 군집을 확인해주는 점이라고 보는 것이 더 맞다.

### 4-3. 코깅이 더 현실적인 균형 후보

다음 점들은 최고 토크는 아니지만 코깅이 확실히 낮다.

- `run 129`
  - average torque = `43.77 N.m`
  - ripple = `26.51 %`
  - cogging = `0.0357 N.m`
  - force = `888 N`

- `run 104`
  - average torque = `39.39 N.m`
  - ripple = `23.98 %`
  - cogging = `0.0577 N.m`
  - force = `952 N`

- `run 117`
  - average torque = `37.12 N.m`
  - ripple = `24.41 %`
  - cogging = `0.0311 N.m`
  - force = `1013 N`

이 점들은 `run 8`, `run 121`보다 torque는 낮지만,
코깅을 크게 줄이면서도 리플을 비교적 잘 유지한다.

## 5. 이번 결과가 의미하는 것

이번 wide run으로부터 얻는 해석은 다음과 같다.

### 5-1. 현재 범위에서 torque-ripple Pareto는 여전히 약하다

범위를 넓혀도 평균 토크와 토크 리플이 여전히 같은 방향으로 개선되는 구간이 강했다.

즉 지금 탐색 범위에서는

- `maximize average torque`
- `minimize torque ripple`

를 독립적인 상충 목적함수로 두는 의미가 아직 약하다.

### 5-2. 진짜 충돌은 cogging에서 더 잘 보인다

최고 토크권 후보들은 `cogging torque`가 다시 커지는 경향이 있다.

따라서 이후 최적화는 오히려 다음 식이 더 자연스럽다.

```text
maximize average torque
subject to torque ripple <= threshold
subject to cogging torque <= threshold
subject to force <= threshold
```

즉 `Pareto front`보다 `고토크 feasible region`을 찾는 쪽이 더 실용적이다.

### 5-3. good region은 확인되었다

`run 8`과 `run 121`이 서로 매우 가까운 위치에서 둘 다 강한 성능을 보였기 때문에,
좋은 결과가 단일 점 우연은 아니라는 것은 확인되었다.

즉

- `thickness`: 약 `4.8 ~ 5.0 mm`
- `length`: 약 `16.0 ~ 16.5 mm`
- `v_angle`: 약 `55 ~ 60 deg`

부근이 핵심 고성능 구간으로 보인다.

## 6. 추천 다음 단계

지금 기준으로 가장 자연스러운 다음 단계는 이렇다.

1. `run 8`, `run 121` 주변에서 국소 refine DOE 수행
2. 목적을 `최대 토크`로 두고
3. `ripple`, `cogging`, `force`는 제약 또는 필터로 처리
4. 필요하면 그 후에만 surrogate/DNN을 다시 학습

즉 다음 탐색은 넓게 다시 퍼뜨리기보다,
이미 확인된 고성능 구간을 좁게 다시 파는 것이 더 효율적이다.

## 7. 3목적 Pareto: 평균 토크, 토크 리플, 자석 면적

이번에는 당신 지적대로 `자석 면적`을 따로 목적함수에 넣어서 다시 보았다.

여기서는 다음처럼 두었다.

- `f1 = - loaded_torque_mean`
- `f2 = loaded_torque_ripple_pct`
- `f3 = magnet area`

여기서 중요한 점은 이 자석이 직사각형이 아니라 `평행사변형`이라는 것이다.

따라서 자석 1장의 면적은 단순히 `length x thickness`가 아니라

$$
\text{area}_{1\ magnet}
=
(\text{magnet length}) \times (\text{magnet thickness}) \times \sin(\text{v\_angle})
$$

가 된다.

그래서 총 자석 면적 proxy는

$$
f_3 \propto 8 \times (\text{magnet thickness}) \times (\text{magnet length}) \times \sin(\text{v\_angle})
$$

로 두었다.

여기서 `8`은 `4 pole x pole당 2 magnet`을 반영한 상수다.  
depth와 pole 수가 고정이므로, 3D 체적 비교를 하더라도 순서는 이 2D 면적 proxy와 동일하다.

### 7-1. 왜 이게 중요한가

이전의 `torque-ripple` 2목적만 보면 높은 토크 점들이 리플도 함께 낮아서,
마치 전부 같은 방향으로 좋아지는 것처럼 보였다.

그런데 실제로는 그 점들이 더 넓은 자석 면적을 쓰고 있었기 때문에,
`magnet area`를 빼면 불공정 비교가 될 수 있다.

즉 이번 3목적 Pareto는

```text
더 큰 토크
더 작은 리플
더 적은 자석 면적
```

사이의 진짜 trade-off를 보기 위한 것이다.

### 7-2. 결과 그림

![3obj Torque Ripple Magnet Area](/Users/dohyunkim/Documents/Window/femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add33/combined48_pareto_3obj_torque_ripple_color_magnet_area.png)

![3obj Torque Magnet Area](/Users/dohyunkim/Documents/Window/femm_output_v_ipm_m19_axis_shortedge_ccf_wide_add33/combined48_pareto_3obj_torque_vs_magnet_area.png)

### 7-3. 결과 해석

3목적 Pareto 점 개수는 `17개`였다.

중요한 건, 이제 Pareto set이 `run 8`, `run 121` 같은 고토크 점만으로 끝나지 않는다는 점이다.

예를 들면 다음 점들이 작은 자석 면적으로 새롭게 의미를 가진다.

- `run 111`
  - torque = `18.64 N.m`
  - ripple = `35.96 %`
  - magnet area proxy = `215.10`

- `run 101`
  - torque = `19.80 N.m`
  - ripple = `35.15 %`
  - magnet area proxy = `215.28`

- `run 126`
  - torque = `25.18 N.m`
  - ripple = `34.44 %`
  - magnet area proxy = `264.49`

- `run 113`
  - torque = `37.76 N.m`
  - ripple = `28.44 %`
  - magnet area proxy = `305.40`

즉 자석 면적을 훨씬 적게 쓰면서도 일정 수준의 토크를 내는 점들은,
2목적에서는 묻혔지만 3목적에서는 non-dominated가 된다.

반대로 최고 토크 쪽에서는 여전히 다음 두 점이 끝단을 이룬다.

- `run 121`
  - torque = `48.99 N.m`
  - ripple = `21.66 %`
  - magnet area proxy = `525.98`

- `run 8`
  - torque = `50.73 N.m`
  - ripple = `22.09 %`
  - magnet area proxy = `554.26`

이 두 점은 자석 면적도 큰 편이기 때문에,
`성능 극대화` 쪽 Pareto 끝점이라고 해석할 수 있다.

### 7-4. 이번 3목적 Pareto가 말해주는 것

이번 결과는 당신 말이 맞다는 걸 보여준다.

- `torque-ripple`만 보면 역상관처럼 보여서 trade-off가 약해 보였다
- 하지만 `magnet area`를 넣으면 진짜 trade-off 구조가 나타난다
- 즉 숨겨진 축은 자석 면적이었다

그래서 이후 최적화는 다음 두 방향 중 하나가 더 자연스럽다.

1. `3목적 Pareto`
   - maximize torque
   - minimize ripple
   - minimize magnet area

2. `단일 목적 + 제약`
   - maximize torque
   - subject to ripple, magnet area, cogging, force limits

만약 비용이나 희토류 사용량이 중요하면,
지금부터는 `magnet area`를 반드시 포함하는 쪽이 맞다.
