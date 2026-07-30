# CCF DNN + NSGA Notes

최종 갱신: 2026-07-22

참고 실습 노트북:

- [/Volumes/Untitled/Users/han/Desktop/Modelica/Modelica7/(bonus)DNN + NSGA.ipynb](/Volumes/Untitled/Users/han/Desktop/Modelica/Modelica7/(bonus)DNN%20+%20NSGA.ipynb)
- [/Volumes/Untitled/Users/han/Desktop/Modelica/Modelica7/2-2교시)데이터적용_DNN + NSGA.ipynb](/Volumes/Untitled/Users/han/Desktop/Modelica/Modelica7/2-2%E1%84%80%E1%85%AD%E1%84%89%E1%85%B5)%E1%84%83%E1%85%A6%E1%84%8B%E1%85%B5%E1%84%90%E1%85%A5%E1%84%8C%E1%85%A5%E1%86%A8%E1%84%8B%E1%85%AD%E1%86%BC_DNN%20+%20NSGA.ipynb)

## 목적

이번 메모는 실습용 `DNN + NSGA-II` 노트북 구조를 현재 `axis shortedge CCF` 데이터에 어떻게 대응시킬지 정리한 것이다.

핵심 질문은 두 가지다.

1. 현재 CCF 데이터에도 DNN을 적용할 수 있는가
2. 적용한다면 NSGA의 목적함수는 어떻게 둘 것인가

## 결론 먼저

짧게 말하면 다음과 같다.

- `DNN 구조 자체는 적용 가능하다`
- 다만 현재 CCF는 `3입력 4출력` 문제다
- 실습 노트북의 `4입력 4출력` 구조를 그대로 복사하면 안 된다
- NSGA는 일단 `제약함수 없이 목적함수 2개`로 시작해도 된다
- 단, 현재 데이터가 `15점`뿐이라 DNN surrogate의 신뢰도는 낮을 수 있다

즉

$$
\text{구조적으로는 가능} \quad \text{but} \quad \text{지금 데이터 수는 아직 적다}
$$

라고 보는 것이 정확하다.

## 지금 하려는 실습형 흐름

당신이 기억한 `25~50개만 가지고 1000개처럼 퍼뜨리던 방식`은 보통 아래 구조다.

```text
실제 FEMM 데이터 25~50개
-> DNN surrogate 학습
-> 설계변수 범위 안에서 랜덤 후보 1000개 생성
-> DNN이 1000개 출력 예측
-> 산포도 / Pareto front 확인
-> 상위 후보만 다시 FEMM 재검증
```

즉 `1000개`는 실제 해석 데이터가 아니라, 대개 surrogate가 예측한 후보군이다.

이번 CCF에서도 같은 식으로 접근할 수 있다.

- 실제 측정 데이터: 현재 `15개`
- 입력 변수: `magnet_thickness_mm`, `magnet_length_mm`, `v_angle_deg`
- surrogate 출력: `loaded_torque_mean`, `loaded_torque_ripple_pct`, `cogging_torque_pkpk`, `loaded_force_max`
- 랜덤 후보: 예를 들어 `1000개`

이 흐름을 바로 실행해볼 수 있도록 새 노트북 [CCF_DNN_RANDOM1000_WORKFLOW.ipynb](/Users/dohyunkim/Documents/Window/theory_notes/CCF_DNN_RANDOM1000_WORKFLOW.ipynb)도 추가했다.

## FEMM 실제 해석 포인트 늘리기

surrogate 신뢰도를 올리려면 실제 FEMM 데이터도 함께 늘려야 한다.

이번 작업에서는 다음처럼 확장했다.

- 기존 DOE: `15점`
- 확장 DOE: `50점`
- 구성 방식: `기존 15점 + 추가 35점`
- 추가 35점은 현재 범위
  - `magnet_thickness_mm in [3, 5]`
  - `magnet_length_mm in [13, 16]`
  - `v_angle_deg in [45, 60]`
  안에서 space-filling 형태로 퍼뜨렸다.

관련 파일:

- 50점 설계표: [v_ipm_m19_ccf_axis_parallel_shortedge_design_points_50.csv](/Users/dohyunkim/Documents/Window/v_ipm_m19_ccf_axis_parallel_shortedge_design_points_50.csv)
- 50점 실행 wrapper: [analyze_axis_shortedge_ccf_50point.m](/Users/dohyunkim/Documents/Window/analyze_axis_shortedge_ccf_50point.m)

기존 [analyze_axis_shortedge_ccf.m](/Users/dohyunkim/Documents/Window/analyze_axis_shortedge_ccf.m)도 override를 받을 수 있게 바꿨기 때문에, 15점과 50점 둘 다 같은 본체 로직으로 돌릴 수 있다.

## 시간 때문에 한 번만 더 돌리고 싶을 때

만약 `현재 좁은 범위 50점`을 다시 도는 대신, `한 번의 추가 FEMM run으로 범위 자체를 넓혀 보고 싶다`면 다음 구성이 더 실용적이다.

- 이미 확보한 실제 데이터: `기존 15점`
- 새로 추가할 데이터: `넓은 범위 35점`
- 나중에 합치면 총 `50점`

넓은 범위 예시는 다음처럼 잡을 수 있다.

- `magnet_thickness_mm in [2.5, 5.5]`
- `magnet_length_mm in [12.0, 17.0]`
- `v_angle_deg in [40.0, 65.0]`

관련 파일:

- 넓은 범위 추가 DOE: [v_ipm_m19_ccf_axis_parallel_shortedge_design_points_wide_add35.csv](/Users/dohyunkim/Documents/Window/v_ipm_m19_ccf_axis_parallel_shortedge_design_points_wide_add35.csv)
- 실행 wrapper: [analyze_axis_shortedge_ccf_wide_add35.m](/Users/dohyunkim/Documents/Window/analyze_axis_shortedge_ccf_wide_add35.m)

이 방식의 장점은:

- 기존 15점은 버리지 않는다
- 새 FEMM 해석은 `35점`만 추가하면 된다
- 범위를 넓혀서 `torque-ripple trade-off`가 실제로 나타나는지 더 빨리 확인할 수 있다

단, 범위를 넓히면 geometry failure나 비정상 형상이 나올 수 있으니, 첫 실행에서는 progress를 자주 보면서 실패 케이스가 많은지 확인하는 것이 좋다.

## 실습 노트북에서 배워야 할 구조

실습 노트북의 좋은 점은 전반 구조가 분명하다는 것이다.

```text
DOE data
-> input/output scaling
-> DNN surrogate training
-> predicted outputs
-> NSGA-II optimization
-> Pareto front visualization
```

이 전체 흐름은 현재 CCF 문제에도 그대로 유효하다.

실습에서 본 핵심 구성 요소는 다음과 같다.

### 1. 입력과 출력 테이블 분리

입력 `X`와 출력 `Y`를 separate table로 두고 정규화한다.

```python
scaler_input = MinMaxScaler()
scaler_output = MinMaxScaler()
X_scaled = scaler_input.fit_transform(X)
Y_scaled = scaler_output.fit_transform(Y)
```

### 2. 다출력 DNN

실습의 데이터 적용 버전은 `4출력`을 한 번에 예측하는 모델이다.

```python
self.l4 = Dense(4, activation='linear', name='output')
```

이 구조는 중요한 포인트다. 즉 `출력마다 모델 하나`가 아니라, 하나의 네트워크가 여러 출력을 동시에 예측할 수 있다.

### 3. NSGA-II 연결

DNN이 surrogate로 예측한 출력 `y1, y2, y3, y4`를 objective 또는 constraint에 넣는다.

```python
f1 = y1(x)
f2 = y2(x)
```

이 아이디어는 CCF에도 동일하게 적용할 수 있다.

## 왜 실습은 4입력 4출력이었고, 지금은 3입력 4출력인가

당신 기억이 맞다. 실습에서는 `4입력 4출력`이었다.

하지만 DNN이 꼭 `4입력 4출력`이어야 하는 것은 아니다.  
DNN은 입력 개수와 출력 개수에 맞게 첫 레이어와 마지막 레이어 shape만 바꾸면 된다.

즉 일반적으로는

$$
\mathbb{R}^{n_{\text{in}}} \rightarrow \mathbb{R}^{n_{\text{out}}}
$$

형태의 함수 근사기다.

그래서 현재 CCF에서는 다음처럼 바뀐다.

### 실습 예제

- 입력 `4개`
- 출력 `4개`

### 현재 CCF

- 입력 `3개`
  - `magnet_thickness_mm`
  - `magnet_length_mm`
  - `v_angle_deg`
- 출력 `4개`
  - `loaded_torque_mean`
  - `loaded_torque_ripple_pct`
  - `cogging_torque_pkpk`
  - `loaded_force_max`

즉 이번 문제는

```text
3 inputs -> DNN -> 4 outputs
```

로 보면 된다.

따라서 실습 노트북의 다음 부분은 바뀌어야 한다.

```python
input = Input((4,))
```

현재 문제에서는

```python
input = Input((3,))
```

가 되어야 한다.

마지막 출력 레이어는 여전히 `Dense(4)`가 자연스럽다.

## 현재 CCF에서의 입출력 정의

현재 surrogate를 위한 추천 테이블 정의는 다음과 같다.

### 입력 X

$$
X =
\begin{bmatrix}
\text{magnet\_thickness\_mm} &
\text{magnet\_length\_mm} &
\text{v\_angle\_deg}
\end{bmatrix}
$$

### 출력 Y

$$
Y =
\begin{bmatrix}
\text{loaded\_torque\_mean} &
\text{loaded\_torque\_ripple\_pct} &
\text{cogging\_torque\_pkpk} &
\text{loaded\_force\_max}
\end{bmatrix}
$$

필요하면 `loaded_force_mean`을 추가해 `5출력`으로 갈 수도 있지만, 시작은 `4출력`이 가장 깔끔하다.

## 현재 단계의 목적함수 정의

지금은 일단 `제약함수 없이 목적함수만` 두는 접근이 괜찮다.

가장 자연스러운 1차안은 다음이다.

### 목적함수 2개

```text
f1 = - loaded_torque_mean
f2 = loaded_torque_ripple_pct
```

의미는 간단하다.

- 평균토크는 크게 하고 싶으니 `-mean_torque`를 최소화
- 토크리플은 작게 하고 싶으니 그대로 최소화

즉 Pareto front는

$$
\text{high torque} \quad vs \quad \text{low ripple}
$$

의 trade-off를 보여준다.

### 코깅과 force는 어떻게 보나

초기 단계에서는 목적함수에 넣지 않고 후처리로 보는 것도 충분히 합리적이다.

즉 흐름은

```text
NSGA-II with 2 objectives
-> Pareto candidates
-> check cogging and force afterward
```

로 갈 수 있다.

이 방식의 장점은, 초반에 불필요하게 탐색공간을 좁히지 않는다는 점이다.

## DNN은 지금 가능한가

이 질문에는 답을 두 층으로 나눠야 한다.

### 1. 구조적으로 가능한가

가능하다.

현재 문제는 단지

```text
3 inputs, 4 outputs
```

이고, DNN은 이런 mapping을 충분히 표현할 수 있다.

실습에서 `4입력 4출력`을 했다고 해서 `3입력 4출력`이 안 되는 것은 전혀 아니다.

### 2. 지금 데이터로 신뢰할 수 있는가

이건 조심해야 한다.

현재 CCF DOE는 `15점`뿐이다.

입력은 3개지만 출력은 4개고, 우리가 원하려는 것은 단순 interpolation이 아니라 surrogate 기반 최적화다. 이 경우 DNN이 지나치게 작은 데이터셋을 외워버릴 가능성이 높다.

즉

```text
가능 = yes
바로 믿고 최적화에 쓰기 = cautious
```

라고 보는 게 맞다.

## 실무 판단

현재 단계에서는 다음 중 하나로 시작하는 것이 좋다.

### 선택 A: DNN 구조는 유지하되 해석용으로만 사용

- 실습 노트북을 `3입력 4출력`으로 수정
- 학습 후 적합 정도 확인
- NSGA는 exploratory하게만 사용

이 경우 surrogate는 아이디어 확인용이고, 최종 의사결정은 추가 FEM으로 검증해야 한다.

### 선택 B: 현재는 DNN 대신 더 가벼운 surrogate 사용

- `2차 반응표면`
- `Gaussian Process / Kriging`

현재 데이터 규모에서는 오히려 이쪽이 더 안정적일 가능성이 크다.

## 현재 문제에 맞춘 최소 구조

개념적으로는 다음과 같이 생각하면 된다.

```python
X = [
    magnet_thickness_mm,
    magnet_length_mm,
    v_angle_deg
]

Y = [
    loaded_torque_mean,
    loaded_torque_ripple_pct,
    cogging_torque_pkpk,
    loaded_force_max
]
```

DNN은

```python
Input((3,))
...
Dense(4, activation='linear')
```

형태가 되고,

NSGA 목적함수는 우선

```python
f1 = - torque_mean
f2 = torque_ripple
```

만 둔다.

## 한 줄 정리

이번 CCF 문제는

```text
4입력 4출력 실습을 그대로 복사하는 문제는 아니고,
3입력 4출력 surrogate로 재구성하는 문제다.
```

그리고 DNN은 `가능`하지만, `지금 15점 데이터에서 바로 강한 surrogate라고 믿는 것`은 별개의 문제다.
