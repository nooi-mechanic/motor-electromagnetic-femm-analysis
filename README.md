# FEMM MATLAB/Octave Motor Analysis

이 저장소는 FEMM에서 사용할 SPM 및 V-IPM 모터 모델 생성, 토크 스윕,
커뮤테이션 검증, 에어갭 민감도 분석용 MATLAB/Octave 스크립트를 담고
있습니다.

## Featured study

### [Double-layer IPM design study](reports/double_layer_ipm/README.md)

pyFEMM으로 더블레이어 IPM을 설계하고 DOE, DNN 대리모델, 실제 FEMM
재검증, 공극자속 및 Maxwell stress 분석까지 이어 간 실험 보고서입니다.
각 단계의 핵심 결과, 그림, 실행된 노트북과 요약 데이터를 함께 볼 수 있습니다.

## 디렉토리

- `octave/`: 초기 MATLAB/Octave 호환 모델 생성 및 스윕 코드
- `matlab/`: Windows VM의 MATLAB/FEMM 해석 소스 스냅샷
- `docs/`: 해석 기준, 확정 결과 및 원격 MATLAB 운영 인수인계
- `reports/double_layer_ipm/`: 더블레이어 IPM pyFEMM 설계·검증 보고서

`matlab/`에는 소스와 설계점 CSV만 보관합니다. 대용량 FEMM 해석 결과,
로그, 임시 MAT 파일과 데몬 상태 파일은 Git에서 제외합니다.

## 포함된 파일

- `octave/generate_spm_motor.m`
  - FEMM를 열고 새 문서를 만든 뒤
  - 자석, 코어, 실링 재료를 정의하고
  - SPM 모터 형상을 그린 다음
  - 권선과 공기영역, 경계조건을 설정하고
  - 최종적으로 `spm.fem` 파일로 저장합니다

- `octave/generate_v_ipm_motor.m`
  - 기존 스테이터와 에어갭 조건을 유지한 상태에서
  - 로터만 V형 IPM(Interior Permanent Magnet) 구조로 생성하고
  - 최종적으로 `v_ipm_motor.fem` 파일로 저장합니다

## 필요한 환경

- [FEMM](https://www.femm.info/wiki/HomePage)
- GNU Octave 또는 MATLAB 호환 실행 환경

참고:

- 이 스크립트는 `openfemm()` 기반 자동화를 전제로 합니다.
- FEMM 자동화는 일반적으로 Windows 환경에서 많이 사용됩니다.
- 현재 코드는 해석 실행이나 결과 추출보다 모델 생성에 초점이 맞춰져 있습니다.

## 사용 방법

1. FEMM가 설치된 환경에서 Octave 또는 MATLAB을 엽니다.
2. `octave/generate_spm_motor.m` 파일을 실행합니다.
3. 실행이 끝나면 작업 결과로 `spm.fem` 파일이 저장됩니다.

예시:

```octave
run("octave/generate_spm_motor.m")
```

V형 IPM 버전 예시:

```octave
run("octave/generate_v_ipm_motor.m")
```

## 현재 코드가 하는 일

- 문제 정의 단위를 `millimeters` 기준으로 설정
- 코어 B-H 커브와 자석 재료 정의
- 회전자 자석 및 실링 영역 생성
- 고정자 슬롯과 치 형상 생성
- 3상 권선 블록 라벨 배치
- 외곽 공기영역 및 경계조건 설정
- `spm.fem` 저장
- `v_ipm_motor.fem` 저장

## MATLAB/FEMM 해석

Windows VM의 MATLAB Desktop에서 FEMM을 연동해 실행합니다. 주요 진입점과
원격 작업 큐 사용법은 `matlab/README.md`와
`docs/NEXT_STEPS_FEMM_MATLAB.md`를 참고하십시오.

## 디렉토리 구조

```text
.
├── README.md
├── docs
│   └── NEXT_STEPS_FEMM_MATLAB.md
├── matlab
│   ├── README.md
│   └── *.m
├── octave
    ├── generate_spm_motor.m
    └── generate_v_ipm_motor.m
└── reports
    └── double_layer_ipm
        ├── README.md
        └── 01_ccf_50point ... 05_inner_angle_ripple_physics
```
