# pyFEMM motor design studies

pyFEMM과 FEMM 2D 유한요소해석을 이용한 IPM 모터 설계·최적화 연구 저장소다.
설계 의도, DOE 구성, 대리모델 탐색, FEMM 재검증과 물리 해석을 실험별
리포트로 정리한다.

## Double-layer IPM design study

[![Double-layer IPM rotor geometry](reports/double_layer_ipm/05_inner_angle_ripple_physics/figures/figure_01.png)](reports/double_layer_ipm/README.md)

두 겹의 V형 영구자석을 갖는 IPM 로터에서 자석 배치가 평균토크,
토크리플과 자석 사용량에 미치는 영향을 분석했다.

- 결합형 4인자 CCF 50점 DOE
- 55–90° 확장 DOE와 DNN ensemble 탐색
- 최적 후보 5개의 실제 FEMM 재검증
- 내·외측각 독립 Sobol 64점 분석
- 공극자속 FFT와 Maxwell stress 기반 리플 원인 분석

**[전체 연구 리포트 보기 →](reports/double_layer_ipm/README.md)**

## Repository structure

```text
reports/
└── double_layer_ipm/
    ├── README.md
    ├── 01_ccf_50point/
    ├── 02_55to90_surrogate_validation/
    ├── 03_best_worst_flux_path/
    ├── 04_independent_angle_sobol/
    └── 05_inner_angle_ripple_physics/
```

각 실험 폴더는 분석 리포트, 실행 결과가 포함된 Jupyter notebook, 대표 그림,
요약 데이터와 재현용 pyFEMM 스크립트로 구성된다.

## Environment

- Windows
- [FEMM](https://www.femm.info/wiki/HomePage)
- Python / pyFEMM
- Jupyter Notebook

해석 결과는 2D FEMM 모델과 각 실험에서 정의한 운전조건에 기반한다.
