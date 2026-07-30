# V-IPM 이론 정리

최종 갱신: 2026-07-21

## 에어갭 자기저항과 평균 토크 경향

에어갭이 커지면 공극 자기저항은 증가한다. 원통형 공극에서 자속이 반지름 방향으로 건너간다고 보면 자속 통과 면적은 원통 옆면이므로

$$
S(r) = 2 \pi r L
$$

가 된다. 따라서 미소 반경 구간 `dr`의 공극 자기저항은

$$
d\mathcal{R} = \frac{dr}{\mu \, 2 \pi r L}
$$

이고 이를 `r1`에서 `r2`까지 적분하면

$$
\mathcal{R}_g = \frac{1}{2 \pi \mu L} \ln\left(\frac{r_2}{r_1}\right)
$$

을 얻는다.

공극 두께 `g = r2 - r1`가 평균 반경 `r_m`에 비해 매우 작으면

$$
\ln\left(\frac{r_2}{r_1}\right) \approx \frac{g}{r_m}
$$

$$
r_m \approx \frac{r_1 + r_2}{2}
$$

로 근사할 수 있으므로

$$
\mathcal{R}_g \approx \frac{g}{\mu \, 2 \pi r_m L}
$$

가 된다. 따라서 얇은 공극 근사에서는

- 공극 자기저항은 `g`에 거의 비례한다.
- 공극 자기저항은 평균 반경 `r_m`에 반비례한다.
- 공극 자기저항은 적층 길이 `L`에 반비례한다.

이번 `g = 0.5 ~ 0.9 mm` 범위 FEMM 결과에서 평균 토크가 거의 선형적으로 감소한 것은 위 얇은 공극 근사와 잘 부합한다. 실제 선형 적합은

$$
T_{\mathrm{mean}} \approx 39.5902 - 5.0017 \, g(\mathrm{mm})
$$

$$
R^2 = 0.99894
$$

로 나왔으므로 현재 범위에서는 에어갭 증가에 따른 평균 토크 감소를 거의 직선 관계로 보아도 무방하다. 다만 이 결론은 현재의 좁은 공극 범위에 대한 국소 근사이며, 더 넓은 범위에서는 포화와 누설자속 때문에 비선형성이 커질 수 있다.

정리하면 이론적으로는

$$
\text{airgap 증가} \rightarrow \text{공극 자기저항 증가} \rightarrow \text{자속 감소} \rightarrow \text{평균 토크 감소}
$$

가 기본 방향성이며, 실제 감소량은 자석 형상, 철심 포화, 누설자속, 슬롯 구조 등 다른 설계변수와의 상호작용으로 결정된다.

## V-IPM에서 magnet thickness, magnet length, V-angle를 왜 최적화하는가

V-IPM은 자석 토크와 reluctance torque를 동시에 사용할 수 있다는 점이 핵심이다. `dq` 축 관점의 대표 토크식은 부호 관례에 따라 다음과 같이 쓸 수 있다.

$$
T = \frac{3}{2} p \left( \lambda_m i_q + (L_d - L_q) i_d i_q \right)
$$

또는

$$
T = \frac{3}{2} p \left( \lambda_m i_q + (L_q - L_d) i_d i_q \right)
$$

핵심은 동일하다.

- 첫 항은 자석 토크다.
- 둘째 항은 `d축`과 `q축`의 인덕턴스 차이에서 나오는 reluctance torque다.

`L_d`와 `L_q`가 다른 이유는 `d축`과 `q축`에서 자속이 지나는 자기회로가 다르기 때문이다.

- `d축`은 자석 축과 더 정렬된 방향이므로 자속이 자석과 자석 근처 경로를 직접 많이 지난다.
- `q축`은 자석 사이 철 브리지와 우회 철심 경로를 더 많이 활용할 수 있다.
- 자석은 철심보다 상대 투자율이 훨씬 작기 때문에 `d축`과 `q축`의 등가 자기저항이 달라진다.

이 때문에 IPM에서는 보통 `L_q > L_d`가 되고, 이 saliency 차이가 reluctance torque 원천이 된다.

현재 최적화 변수들의 물리적 의미는 다음과 같다.

### magnet thickness

- 자석 단면 두께를 바꿔 자석이 공급하는 자속량 `lambda_m`에 직접 영향을 준다.
- 너무 얇으면 자석 토크가 부족해질 수 있다.
- 너무 두꺼우면 누설자속 증가, 국부 포화, 브리지 감소 등 부작용이 생길 수 있다.
- 결과적으로 `lambda_m`, 포화 분포, 일부 `L_d/L_q` 특성을 동시에 건드린다.

### magnet length

- 자석 유효 부피와 끝단 누설 특성을 바꾼다.
- 길어질수록 자석 토크 성분을 늘릴 수 있지만 outer bridge와 inner bridge를 잠식해 포화와 기계적 여유를 악화시킬 수 있다.
- q축 철심 경로를 줄이면 saliency가 줄어 reluctance torque가 오히려 손해를 볼 수도 있다.

### V-angle

- 자석이 벌어지는 정도를 정하는 형상 변수다.
- 자석 자속의 공간 분포와 d/q축 자기회로 차이를 크게 바꾼다.
- 브리지 포화 위치, 자속 집중, 코깅토크, 토크리플, radial force에도 함께 영향을 준다.

직관적으로 보면

- `magnet thickness`와 `magnet length`는 자석을 얼마나 강하고 크게 쓰는지에 가깝고
- `V-angle`은 그 자속과 saliency를 어떤 공간 배치로 사용할지를 정하는 변수다.

따라서 이번 DOE에서 `magnet thickness`, `magnet length`, `V-angle`을 동시에 보는 이유는 단순 자석 토크만이 아니라

$$
\lambda_m,\; L_d,\; L_q,\; \text{포화},\; \text{누설자속},\; \text{코깅토크},\; \text{토크리플},\; \text{radial force}
$$

를 함께 바꾸기 때문이다.

한 줄 요약:

$$
\text{V-IPM 최적화는 자석 자속 } \lambda_m \text{와 saliency } (L_q - L_d) \text{의 균형을 설계하는 작업이다.}
$$

## Ld, Lq부터 T-N 커브와 효율까지 이어지는 이론 골격

이 아래 내용은 `Ld`, `Lq`, 토크식, `T-N` 커브, 효율식이 어떻게 하나의 체계로 연결되는지 정리한 공부 메모다. 핵심은 모든 식이 결국

$$
\text{형상} \rightarrow \text{자속 경로} \rightarrow \lambda_d,\lambda_q \rightarrow L_d,L_q,\psi_f \rightarrow T,\;V,\;P,\;\eta
$$

의 순서로 연결된다는 점이다.

### 1. 출발점: 자속결합과 인덕턴스 정의

권선에 전류가 흐르면 자계가 생기고, 그 자계가 철심과 공극과 자석을 지나 자속을 만든다. 이 자속이 권선과 결합한 값이 자속결합 `flux linkage`다.

축별 자속결합을

$$
\lambda_d,\;\lambda_q
$$

라고 두면 인덕턴스의 가장 기본적인 정의는 다음 미분식이다.

$$
L_d = \frac{\partial \lambda_d}{\partial i_d}, \qquad
L_q = \frac{\partial \lambda_q}{\partial i_q}
$$

즉 `Ld`, `Lq`는 임의의 경험상수가 아니라

$$
\text{전류를 조금 바꿨을 때 자속결합이 얼마나 바뀌는가}
$$

를 나타내는 기울기다.

선형 근사와 교차결합 무시가 가능할 때는 보통

$$
\lambda_d = L_d i_d + \psi_f
$$

$$
\lambda_q = L_q i_q
$$

로 쓴다. 여기서 `\psi_f`는 영구자석이 만드는 자속결합이다.

### 2. 왜 d축과 q축이 다르게 보이나

IPM에서는 회전자 형상 때문에 두 축의 자기회로가 서로 다르다.

- `d축`은 자석 축과 정렬된 방향이다.
- `q축`은 자석 축과 직교하는 방향이다.

이 때문에 자속이 지나는 경로와 등가 자기저항이 달라지고, 보통

$$
L_q > L_d
$$

가 된다. 이 차이를 `saliency`라고 본다.

따라서 로터 형상을 바꾸는 일은 본질적으로

$$
\psi_f,\;L_d,\;L_q
$$

를 동시에 바꾸는 일이다.

### 3. dq 전압방정식

3상 `abc` 전류는 시간에 따라 계속 회전하므로 그대로는 해석이 불편하다. 그래서 회전자와 함께 도는 `dq` 좌표계로 변환하면 정상상태 해석이 크게 단순해진다.

대표적인 `dq` 전압방정식은 다음과 같다.

$$
v_d = R_s i_d + \frac{d\lambda_d}{dt} - \omega_e \lambda_q
$$

$$
v_q = R_s i_q + \frac{d\lambda_q}{dt} + \omega_e \lambda_d
$$

정상상태에서 `d/dt` 항을 무시하고 위의 선형 자속식을 넣으면

$$
v_d \approx R_s i_d - \omega_e L_q i_q
$$

$$
v_q \approx R_s i_q + \omega_e (L_d i_d + \psi_f)
$$

가 된다.

이 식이 중요한 이유는 속도가 올라갈수록 `\omega_e`가 커지고, 결국 전압 제한이 속도영역을 결정하기 때문이다.

### 4. 토크식은 어떻게 나오나

IPM의 대표 토크식은 자기 co-energy 또는 `dq` 전력식을 통해 다음처럼 정리된다.

$$
T = \frac{3}{2} p \left( \psi_f i_q + (L_d - L_q) i_d i_q \right)
$$

부호 관례에 따라 두 번째 항이 `(L_q - L_d)i_d i_q`처럼 보이는 책도 있지만 물리적 의미는 같다.

- 첫 항 `\psi_f i_q`는 자석 토크다.
- 둘째 항은 saliency에서 나오는 reluctance torque다.

즉 IPM은

$$
\text{자석 토크} + \text{릴럭턴스 토크}
$$

를 동시에 사용한다.

그래서 `Ld`, `Lq`를 바꾸는 로터 형상 최적화는 평균토크와 토크리플을 동시에 건드릴 수 있다.

### 5. T-N 커브는 어디서 나오나

`T-N` 커브는 토크식 하나만으로 정해지지 않고, 토크식에 전류 제한과 전압 제한을 함께 걸어서 얻는다.

전류 제한은 보통

$$
i_d^2 + i_q^2 \le I_{\max}^2
$$

로 쓴다.

전압 제한은 보통

$$
v_d^2 + v_q^2 \le V_{\max}^2
$$

로 쓴다.

저속에서는 `\omega_e`가 작아 전압 여유가 크므로 보통 전류 제한이 먼저 걸린다. 이 영역에서는 거의 일정 토크를 낼 수 있으므로 `constant torque region`이 된다.

속도가 증가하면

$$
v_q \approx \omega_e (L_d i_d + \psi_f)
$$

항이 커지면서 전압 제한이 지배적이 된다. 그러면 더 이상 같은 전류벡터로 같은 토크를 만들 수 없고, `i_d < 0`를 사용해 자속을 약하게 하는 `flux weakening`이 필요해진다.

정리하면

- 저속: 전류 제한 지배 -> 일정 토크 구간
- 고속: 전압 제한 지배 -> 토크 감소 구간

이 두 구간이 이어진 것이 `T-N` 커브다.

### 6. base speed의 의미

`base speed`는 전압 제한이 본격적으로 걸리기 시작하는 속도라고 보면 된다.

아주 거칠게는

$$
V_{\max} \approx \omega_e |\lambda|
$$

조건이 처음 중요해지는 지점이다.

여기서 `|\lambda|`는 `\psi_f`, `L_d`, `i_d`, `L_q`, `i_q`의 조합으로 결정되므로, 결국

$$
L_d,\;L_q,\;\psi_f
$$

가 바뀌면 `base speed`와 `T-N` 커브 전체도 같이 바뀐다.

### 7. 효율식은 어떻게 세우나

효율은 가장 기본적으로

$$
\eta = \frac{P_{\mathrm{out}}}{P_{\mathrm{in}}}
$$

이다.

기계 출력은

$$
P_{\mathrm{out}} = T \omega_m
$$

입력은

$$
P_{\mathrm{in}} = P_{\mathrm{out}} + P_{\mathrm{loss}}
$$

로 본다. 따라서 결국 손실모델이 있어야 효율이 정해진다.

대표 손실은 다음과 같다.

- 동손 `P_{cu}`
- 철손 `P_{core}`
- 자석 손실
- 기계손
- stray loss

동손은 비교적 단순하게

$$
P_{cu} \approx 3 R_s I_{\mathrm{rms}}^2
$$

로 볼 수 있다.

철손은 보통 히스테리시스 손실과 와전류 손실의 합으로 보고, 경험적으로

$$
P_h \propto f B^n
$$

$$
P_e \propto f^2 B^2
$$

형태를 사용한다.

따라서 효율 계산은 본질적으로

$$
\eta = \frac{T \omega_m}{T \omega_m + P_{cu} + P_{core} + P_{pm} + P_{mech} + P_{stray}}
$$

를 평가하는 작업이다.

### 8. FEM은 식을 대체하는가

아니다. FEM은 이론을 대체하기보다, 위 식들 안에 들어가는 실제 함수를 수치적으로 계산해 주는 도구에 가깝다.

예를 들면 FEM으로 구하는 대표 항목은 다음과 같다.

- `\lambda_d(i_d, i_q)`
- `\lambda_q(i_d, i_q)`
- 토크파형
- back-EMF
- 철손
- 자속밀도 분포

즉 이론은 구조를 주고, FEM은 실제 수치를 준다.

### 9. 한 줄로 다시 요약

전동기 이론을 이번 관점에서 아주 짧게 정리하면 다음과 같다.

$$
\text{형상}
\rightarrow
\text{자속 경로와 자기저항}
\rightarrow
\lambda_d,\lambda_q
\rightarrow
L_d,L_q,\psi_f
\rightarrow
\text{토크식과 전압식}
\rightarrow
\text{T-N 커브}
\rightarrow
\text{손실모델}
\rightarrow
\eta
$$

따라서 `Ld/Lq부터 T-N 커브와 효율까지의 원리`를 이해한다는 것은 결국 위 사슬이 어떻게 이어지는지를 이해하는 것이다.

## abc에서 dq로, 그리고 토크식까지의 최소 유도

이번 섹션은 실제로 식이 어떻게 이어지는지를 최소한의 단계만 남겨 정리한 것이다.

### 1. abc 권선 전압식

3상 고정자 권선의 순간 전압식은 각 상마다

$$
v_a = R_s i_a + \frac{d\lambda_a}{dt}
$$

$$
v_b = R_s i_b + \frac{d\lambda_b}{dt}
$$

$$
v_c = R_s i_c + \frac{d\lambda_c}{dt}
$$

로 쓸 수 있다.

벡터로 쓰면

$$
\mathbf{v}_{abc} = R_s \mathbf{i}_{abc} + \frac{d\boldsymbol{\lambda}_{abc}}{dt}
$$

이다.

문제는 `abc` 좌표에서는 회전자 자속이 계속 회전하므로 `\lambda_a,\lambda_b,\lambda_c`가 시간에 따라 복잡하게 변한다는 점이다.

### 2. Clarke-Park 변환의 목적

그래서 3상 교류계를 먼저 정지 좌표 `\alpha\beta`로 옮기고, 다시 회전자와 함께 도는 `dq` 좌표로 옮긴다.

직관적으로는

$$
abc \rightarrow \alpha\beta \rightarrow dq
$$

변환을 통해, 회전자 기준으로 보면 교류가 거의 직류처럼 보이게 만드는 것이다.

이 과정을 거치면 `dq` 전압식은 다음처럼 정리된다.

$$
v_d = R_s i_d + \frac{d\lambda_d}{dt} - \omega_e \lambda_q
$$

$$
v_q = R_s i_q + \frac{d\lambda_q}{dt} + \omega_e \lambda_d
$$

여기서 `\omega_e`는 전기각속도다.

이 식에서 중요한 것은 마지막의 `\pm \omega_e \lambda` 항이다. 이것은 좌표계 자체가 회전하기 때문에 생기는 속도기전력 항이다.

### 3. IPM의 자속결합 모델

IPM의 가장 단순한 `dq` 자속모델은

$$
\lambda_d = L_d i_d + \psi_f
$$

$$
\lambda_q = L_q i_q
$$

이다.

이 모델은 다음 가정을 깔고 있다.

- 영구자석 자속은 주로 `d축`에 놓인다.
- 교차포화와 고조파를 1차 근사에서는 무시한다.
- `Ld`, `Lq`는 동작점 근처의 유효 인덕턴스로 본다.

이 식을 전압식에 대입하면

$$
v_d = R_s i_d + L_d \frac{di_d}{dt} - \omega_e L_q i_q
$$

$$
v_q = R_s i_q + L_q \frac{di_q}{dt} + \omega_e (L_d i_d + \psi_f)
$$

를 얻는다.

정상상태에서 전류가 일정하면 미분항이 거의 사라져

$$
v_d \approx R_s i_d - \omega_e L_q i_q
$$

$$
v_q \approx R_s i_q + \omega_e (L_d i_d + \psi_f)
$$

가 된다.

### 4. 전자기 토크식

`dq` 좌표에서 전자기 출력은

$$
P_e = \frac{3}{2}(v_d i_d + v_q i_q)
$$

로 쓸 수 있다.

이 식에 전압방정식을 넣고 동손 항과 자속 저장 항을 분리하면, 기계로 전달되는 전자기 출력은

$$
P_{em} = \omega_e \frac{3}{2}(\lambda_d i_q - \lambda_q i_d)
$$

꼴로 정리된다.

기계각속도 `\omega_m`와 전기각속도의 관계는

$$
\omega_e = p \omega_m
$$

이므로 토크는

$$
T = \frac{P_{em}}{\omega_m}
= \frac{3}{2} p (\lambda_d i_q - \lambda_q i_d)
$$

이다.

이제 자속식을 대입하면

$$
T = \frac{3}{2}p\left[(L_d i_d + \psi_f)i_q - L_q i_q i_d\right]
$$

즉

$$
T = \frac{3}{2}p\left[\psi_f i_q + (L_d - L_q)i_d i_q\right]
$$

를 얻는다.

이 식이 IPM 토크식의 핵심이다.

### 5. 식의 물리적 의미

위 식의 두 항은 역할이 분명히 다르다.

$$
\frac{3}{2}p \psi_f i_q
$$

는 자석 토크다. 자석이 만든 자속을 `q축 전류`가 밀어주는 항이라고 볼 수 있다.

$$
\frac{3}{2}p (L_d - L_q)i_d i_q
$$

는 릴럭턴스 토크다. 두 축 자기적 비대칭성이 있을 때만 생긴다.

따라서

- `Ld = Lq`이면 릴럭턴스 토크는 0이다.
- `Lq > Ld`인 IPM에서는 적절한 음의 `id`를 사용해 토크를 더 뽑을 수 있다.

### 6. MTPA가 왜 나오는가

전류 크기가 제한된 조건에서 같은 전류로 토크를 최대화하고 싶으면

$$
i_d^2 + i_q^2 = I_s^2
$$

제약 아래에서 토크식을 최대화해야 한다.

이것이 `MTPA(maximum torque per ampere)`의 출발점이다.

SPM에서는 보통 `L_d \approx L_q`라서 `i_d \approx 0`가 자연스럽지만, IPM에서는 saliency 때문에 `i_d < 0`가 더 유리한 경우가 많다.

즉 `Ld`, `Lq`를 이해해야 왜 IPM 제어에서 음의 `id`가 등장하는지도 자연스럽게 이해된다.

### 7. base speed와 flux weakening

속도가 올라가면 전압 제한이 중요해진다. 정상상태에서 저항항을 작다고 보고 간단히 보면

$$
v_q \approx \omega_e (L_d i_d + \psi_f)
$$

가 가장 중요한 항이 된다.

이때 속도가 너무 올라가면 `v_q`가 인버터가 공급할 수 있는 최대 전압을 넘으려 한다. 이 지점이 `base speed` 부근이다.

그래서 더 높은 속도로 가려면

$$
i_d < 0
$$

를 넣어 `L_d i_d + \psi_f`를 줄여야 한다. 이것이 `flux weakening`이다.

즉 flux weakening의 본질은

$$
\text{음의 } i_d \text{로 유효 자속결합을 줄여 전압 제한 안에 남는 것}
$$

이다.

### 8. T-N 커브를 식으로 이해하는 최소 틀

토크-속도 커브는 다음 두 제약을 함께 만족하는 `i_d, i_q` 조합을 각 속도에서 찾는 문제다.

전류 제한:

$$
i_d^2 + i_q^2 \le I_{\max}^2
$$

전압 제한:

$$
v_d^2 + v_q^2 \le V_{\max}^2
$$

저속에서는 전류 제한이 먼저 걸려 거의 일정 토크가 가능하다.

고속에서는 전압 제한이 먼저 걸려 토크가 감소한다.

그래서 결과적으로

- 저속: constant torque
- 고속: flux weakening 이후 decreasing torque

형태의 `T-N` 커브가 나온다.

### 9. 효율과의 연결

토크가 정해지면 출력은

$$
P_{out} = T \omega_m
$$

이다.

효율은

$$
\eta = \frac{P_{out}}{P_{out}+P_{loss}}
$$

이므로, `Ld`, `Lq`, `\psi_f`는 단지 토크만 바꾸는 것이 아니라 전류벡터, 전압크기, 역률, 손실분포까지 바꾸고 결국 효율맵까지 바꾼다.

한 줄로 줄이면

$$
L_d,L_q,\psi_f
\rightarrow
i_d,i_q
\rightarrow
T,\;V,\;I,\;\text{손실}
\rightarrow
\eta
$$

가 된다.
