# FEMM + MATLAB 다음 작업

최종 갱신: 2026-07-28

## 최신 인수인계 (2026-07-28, 다음 작업은 이 섹션부터 읽기)

### 0. 현재 상태와 다음 대화의 시작점

- 기존 18슬롯/4극 V-IPM 모델의 권선, 커뮤테이션, 전회전 토크 및 에어갭 민감도 해석까지 완료했다.
- 최근에는 자석 짧은 변을 좌표축과 평행하게 유지하는 새 자석 형상의 CCF 해석 파일과 설계점 표를 준비했다.
- 사용자가 다음 대화에서 **새로 수행할 해석의 조건을 별도로 전달할 예정**이다.
- 따라서 다음 작업자는 아래 확정 기준과 원격 실행 절차를 먼저 확인한 뒤, 사용자가 새 해석 조건을 말하기 전에는 오래된 스윕을 임의로 재실행하지 않는다.
- 이 섹션 아래의 기존 내용은 상세 이력이다. 서로 충돌할 경우 이 최신 섹션과 실제 현재 파일을 우선한다.

### 1. 확정된 기준 모델

- 모델: 18슬롯, 4극, 3상, 단층 권선 V-IPM
- 확정 권선 배열:

```text
AAC'A'BA'CCB'C'AC'BBA'B'CB'
```

- 검증된 4극 성분:
  - 공간고조파 `n=2`: 약 `1.216 T`
  - 잔류 `n=1`: 약 `0.234 T`
  - `n2/n1`: 약 `5.19`
  - 전류 자계축 기울기: 약 `0.5029`
- 커뮤테이션 기준:
  - 전기각 오프셋 `60 deg`
  - 현재 코드의 기계각 오프셋 표현은 `30 deg` (`4극 = 극쌍수 2`)
- 기준 10 A 전회전 결과:
  - 평균 토크 `37.06395 N.m`
  - 최소/최대 `32.86558 / 41.22737 N.m`
  - 토크 pk-pk `8.36179 N.m`
  - 토크 리플 `22.56044 %`
  - 지배적 토크 리플 기계차수 `12`
- `Fmag = sqrt(Fx^2 + Fy^2)`는 로터에 작용하는 순합력/UMP에 가까운 값이다. 이를 곧바로 공극 전체의 radial force 또는 소음 지표로 해석하지 않는다.

### 2. 완료된 에어갭 민감도

- 고정 스테이터 내경: `64.0 mm`
- 에어갭: `0.5, 0.6, 0.7, 0.8, 0.9 mm`
- 대응 로터 외경: `63.0, 62.8, 62.6, 62.4, 62.2 mm`
- 스테이터 치수는 고정하고 로터 외경만 줄이는 방식이다.
- 자석 형상 유지를 위한 기준식:

```matlab
Seal = Core_ri - gap - PM_r;
```

- 유효 구간에서 평균 토크는 에어갭 증가에 따라 거의 선형 감소했다.

```text
T_mean ~= 39.5902 - 5.0017 * gap(mm)
R^2 ~= 0.99894
```

- 로컬 결과:
  - `airgap_sensitivity_result.mat`
  - `airgap_sensitivity_summary.csv`
  - `airgap_sensitivity_summary_plot.png`
  - `airgap_sensitivity_summary_plot.svg`

### 3. 최근 준비된 axis-shortedge CCF 해석

- 목적: 자석 짧은 변을 좌표축과 평행하게 유지하는 새 형상의 loaded/cogging CCF 해석
- 로컬 핵심 파일:
  - `/Users/dohyunkim/Documents/Window/analyze_axis_shortedge_ccf.m`
  - `/Users/dohyunkim/Documents/Window/export_axis_shortedge_ccf_preview.m`
  - `/Users/dohyunkim/Documents/Window/run_axis_parallel_shortedge_ccf_preview.m`
  - `/Users/dohyunkim/Documents/Window/v_ipm_m19_ccf_axis_parallel_shortedge_design_points.csv`
- VM 배치 위치:

```text
C:\Users\dohyu\Documents\MATLAB\spm
```

- 설계수준:
  - 자석 두께 `3 / 4 / 5 mm`
  - 자석 길이 `13 / 14.5 / 16 mm`
  - V 끼인각 `90 / 105 / 120 deg`
  - 코드의 반각 `v_angle = 45 / 52.5 / 60 deg`
- 한 설계점당 loaded 15개 + cogging 10개, 총 25 FEMM 해석
- 출력 루트:

```text
C:\Users\dohyu\Documents\MATLAB\spm\femm_output_v_ipm_m19_axis_shortedge_ccf
```

- 주요 결과 파일:
  - `axis_shortedge_ccf_partial.mat`
  - `axis_shortedge_ccf_result.mat`
  - `axis_shortedge_ccf_summary.csv`
  - `design_table_used.csv`
- 각 설계점의 세부 로그는 `run_XX_loaded\progress_log.txt`와 `run_XX_cogging\progress_log.txt`에 남는다.
- 이미 반영한 호환성 수정:
  - MATLAB의 63자 파일명 제한 회피
  - MATLAB에서 지원하지 않는 `fflush` 제거
  - `partial_path` 범위 오류 수정
  - `keep_femm_files = false`로 완료된 케이스의 대용량 FEMM 중간 파일 정리
- 형상 미리보기는 사용자가 육안 확인했다. 다만 다음 대화에서 새 해석 조건이 들어오면 이 CCF를 무조건 실행하지 말고 새 요청을 우선한다.

## 원격 MATLAB 표준 실행 절차

### 1. 연결 정보

```text
SSH: dohyun@192.168.195.129
VM 작업 폴더: C:\Users\dohyu\Documents\MATLAB\spm
Mac 작업 폴더: /Users/dohyunkim/Documents/Window
```

- 인증정보는 이 문서에 기록하지 않는다.
- MATLAB/FEMM GUI와 COM 연결 때문에 SSH에서 새 MATLAB을 직접 띄우는 방식은 불안정했다.
- 검증된 방식은 **VM의 이미 열린 MATLAB Desktop 안에서 데몬을 수동으로 한 번 실행하고, 이후 SSH로 작업 큐 파일을 넣는 방식**이다.

### 2. VM MATLAB에서 데몬 시작

MATLAB Desktop을 열고 다음을 직접 실행한다.

```matlab
cd('C:\Users\dohyu\Documents\MATLAB\spm');
codex_matlab_job_daemon
```

정상이면 MATLAB 명령창에 다음 형태가 보인다.

```text
CODEX MATLAB job daemon started.
Watching: C:\Users\dohyu\Documents\MATLAB\spm\codex_job_request.txt
```

- MATLAB을 재시작하면 데몬도 다시 실행해야 한다.
- 데몬이 실행 중인 MATLAB은 명령 프롬프트가 돌아오지 않는 것이 정상이다.

### 3. 원격 실행 전 필수 확인

다음 파일의 수정 시각이 최근인지 확인한다.

```text
codex_job_heartbeat.txt
```

또한 다음을 확인한다.

- `codex_job_running.lock`이 있으면 기존 작업이 실행 중이다.
- `codex_job_request.txt`가 있으면 아직 소비되지 않은 작업이 있다.
- `codex_job_status.txt`의 마지막 상태가 `JOB_START`, `JOB_DONE`, `JOB_FAIL` 중 무엇인지 확인한다.
- 데몬 생존을 확인하지 않고 요청 파일을 덮어쓰지 않는다.

PowerShell 확인 예:

```powershell
cd C:\Users\dohyu\Documents\MATLAB\spm
Get-Item .\codex_job_heartbeat.txt, .\codex_job_running.lock, .\codex_job_request.txt -ErrorAction SilentlyContinue |
    Select-Object Name, LastWriteTime, Length
Get-Content .\codex_job_status.txt -Tail 20
```

### 4. 수정 파일을 VM에 업로드

로컬 파일을 수정했다면 큐 등록 전에 반드시 VM으로 전송한다.

```bash
scp /Users/dohyunkim/Documents/Window/<file>.m \
  dohyun@192.168.195.129:/C:/Users/dohyu/Documents/MATLAB/spm/
```

- 여러 의존 파일이 바뀌었으면 빠짐없이 함께 전송한다.
- 전송 후 VM 파일의 수정 시각 또는 해시를 확인하는 편이 안전하다.

### 5. 작업 큐 등록

SSH로 VM PowerShell에 접속한 뒤 요청 파일에 MATLAB 명령 한 줄을 기록한다.

```powershell
Set-Content `
  -LiteralPath 'C:\Users\dohyu\Documents\MATLAB\spm\codex_job_request.txt' `
  -Value 'clear analyze_axis_shortedge_ccf; analyze_axis_shortedge_ccf' `
  -Encoding ASCII
```

데몬 동작 순서:

1. `codex_job_request.txt` 감지
2. `codex_job_running.lock` 생성
3. 요청 파일 삭제
4. MATLAB base workspace에서 `evalin`으로 명령 실행
5. 성공 시 `JOB_DONE`, 오류 시 `JOB_FAIL`을 `codex_job_status.txt`에 기록
6. lock 파일 삭제

- 새 분석은 위 명령의 스크립트 이름만 바꿔서 실행한다.
- 같은 이름의 스크립트를 수정한 뒤 실행할 때는 `clear <script_name>; <script_name>` 형식을 사용한다.
- 큐 파일은 한 번에 하나만 넣는다. 실행 중인 lock이 있는데 새 요청을 겹쳐 넣지 않는다.

### 6. 가벼운 진행 확인

장시간 해석 중에는 전체 로그를 읽지 말고 아래만 확인한다.

```powershell
tasklist | findstr /i "matlab femm fkern triangle"
Get-Content C:\Users\dohyu\Documents\MATLAB\spm\codex_job_status.txt -Tail 10
```

추가로 확인할 항목:

- `codex_job_heartbeat.txt` 수정 시각
- 현재 설계점의 `progress_log.txt` 마지막 5~10줄
- partial MAT 파일의 수정 시각과 크기
- `JOB_FAIL`, `error`, `failed`, 장시간 정체가 있을 때만 상세 로그 조사

CCF 예:

```powershell
Get-Content C:\Users\dohyu\Documents\MATLAB\spm\femm_output_v_ipm_m19_axis_shortedge_ccf\run_01_loaded\progress_log.txt -Tail 10
```

### 7. 안전한 분석 취소

실행 중인 스윕을 안전하게 취소하려면 작업 폴더에 다음 파일을 만든다.

```powershell
New-Item `
  -ItemType File `
  -Path 'C:\Users\dohyu\Documents\MATLAB\spm\codex_job_cancel.txt' `
  -Force
```

- 스윕 코드는 각 케이스 시작 전에 이 파일을 확인하고 partial 결과를 저장한 뒤 종료한다.
- 이미 실행 중인 `mi_analyze` 한 케이스를 즉시 중단하지는 못하므로 다음 케이스 경계까지 기다린다.
- 취소 목적으로 `matlab.exe`, `femm.exe`, 데몬을 강제 종료하지 않는다.

### 8. 데몬 종료

데몬 자체를 끝내야 하고 MATLAB이 유휴 상태일 때만 다음 파일을 만든다.

```powershell
New-Item `
  -ItemType File `
  -Path 'C:\Users\dohyu\Documents\MATLAB\spm\codex_job_stop.txt' `
  -Force
```

- 사용자의 명시적 요청 없이 데몬을 종료하지 않는다.
- 특히 장시간 작업 중에는 `codex_job_stop.txt`를 만들지 않는다.

### 9. 실패했던 원격 실행 방식

- SSH에서 `matlab -batch`, PowerShell `-r` 등으로 새 MATLAB 프로세스를 직접 실행: FEMM GUI/COM 세션 문제로 불안정
- SSH 세션에서 `AppActivate`/SendKeys: Windows 대화형 세션 격리 때문에 실패
- 대화형 예약 작업: 스크립트 실행 전에 멈추거나 GUI 연결 불안정
- VMware `vmrun -interactive`: VM 암호화 암호와 Windows 로그인 암호가 달라 사용할 수 없었음

따라서 현재 표준은 **MATLAB Desktop 수동 데몬 시작 + SSH/SCP 파일 큐**이다.

## 다음 작업자가 반드시 지킬 것

1. 사용자가 다음 메시지에서 지정할 새 해석의 입력변수, 범위, 출력변수, 전류, 각도 간격을 먼저 확정한다.
2. 기존 기준 모델을 복사해서 새 이름의 분석 스크립트를 만들고, 기존 검증 파일을 덮어쓰지 않는다.
3. 짧은 1케이스 또는 형상 미리보기로 재료 누락, 영역 겹침, 로터/스테이터 간섭을 먼저 검사한다.
4. 로컬 수정 파일을 VM에 업로드한 뒤 데몬 heartbeat와 lock 상태를 확인하고 큐에 넣는다.
5. 장시간 실행 전에 C 드라이브 여유 공간과 `keep_femm_files = false`를 확인한다.
6. 오류가 나면 실패 케이스를 무조건 넘기기 전에 geometry/material 오류인지 먼저 판별한다.
7. `matlab.exe` 종료, 데몬 종료, 대량 파일 삭제는 사용자가 명시적으로 요청한 경우에만 수행한다.

## 최근 인수인계: axis-parallel short-edge 자석 형상

이번 세션의 핵심 변경은 기존 직사각형 V-IPM 자석 대신 다음 형상을 쓰는 것이다.

- 긴 변은 `v_angle_deg` 방향으로 배치
- 짧은 변은 자석 법선이 아니라 `pole axis`와 평행
- 사용자가 의도한 형상은 중앙이 삼각형처럼 열리는 V 형태이며, FEMM 스크린샷으로 확인 완료

현재 기준 파일:

- 로컬 해석 파일: `/Users/dohyunkim/Documents/Window/analyze_axis_shortedge_ccf.m`
- 로컬 프리뷰 파일: `/Users/dohyunkim/Documents/Window/export_axis_shortedge_ccf_preview.m`
- 로컬 짧은 실행 래퍼: `/Users/dohyunkim/Documents/Window/run_axis_parallel_shortedge_ccf_preview.m`
- 로컬 설계표: `/Users/dohyunkim/Documents/Window/v_ipm_m19_ccf_axis_parallel_shortedge_design_points.csv`

VM 업로드 확인 완료 파일:

- `C:\Users\dohyu\Documents\MATLAB\spm\analyze_axis_shortedge_ccf.m`
- `C:\Users\dohyu\Documents\MATLAB\spm\export_axis_shortedge_ccf_preview.m`
- `C:\Users\dohyu\Documents\MATLAB\spm\run_axis_parallel_shortedge_ccf_preview.m`
- `C:\Users\dohyu\Documents\MATLAB\spm\v_ipm_m19_ccf_axis_parallel_shortedge_design_points.csv`

현재 DOE 범위:

```text
magnet_thickness_mm = 3 / 4 / 5
magnet_length_mm = 13 / 14.5 / 16
v_included_angle_deg = 90 / 105 / 120
v_angle_deg = 45 / 52.5 / 60
```

사용자는 preview FEM을 눈으로 확인했고, 이 형상이라면 위 범위로 해석을 진행해도 될 것 같다고 판단했다.

## axis-shortedge 해석 실행 명령

VM MATLAB에서 직접 실행:

```matlab
analyze_axis_shortedge_ccf
```

preview FEM 15개 생성은 필요할 때 아래 명령 사용:

```matlab
export_axis_shortedge_ccf_preview
```

또는

```matlab
run_axis_parallel_shortedge_ccf_preview
```

## 이번 세션에서 이미 수정한 오류

1. 긴 파일명 MATLAB 63자 제한

- 긴 스크립트명 직접 실행 시 MATLAB이 이름을 잘라서 `Unrecognized function or variable` 발생
- 해결: 짧은 실제 실행 파일 `export_axis_shortedge_ccf_preview.m` 생성

2. `fflush` 미지원 오류

- VM MATLAB에서 `fflush(log_fid)`가 인식되지 않아 해석 시작 즉시 중단
- 해결: `analyze_axis_shortedge_ccf.m`의 `log_line`에서 `fflush` 제거

3. `partial_path` 스코프 오류

- `save_partial_results`가 바깥 변수 `partial_path`를 직접 참조하다 실패
- 해결: `save_partial_results(...)`에 필요한 값들을 모두 인자로 전달하도록 수정

## 현재 남아 있을 수 있는 리스크

- `analyze_axis_shortedge_ccf.m`는 이번 세션에서 새로 만든 해석 전용 파일이라 장기 실행 검증은 아직 부족하다.
- 사용자 체감상 설계점 하나당 시간이 꽤 오래 걸릴 수 있다.
- 현재 설정은 설계 1개당 `loaded 15점 + cogging 10점 = 총 25 solve`다.
- 만약 다시 멈추면 가장 먼저 `progress_log.txt`에서 어느 `theta`에서 멈췄는지 확인한다.

## VM spm 폴더 정리 상태

사용자 요청에 따라 구형 preview/debug 파일과 예전 출력 폴더는 삭제했다.

남겨둔 중요 파일:

- `analyze_axis_shortedge_ccf.m`
- `export_axis_shortedge_ccf_preview.m`
- `run_axis_parallel_shortedge_ccf_preview.m`
- `v_ipm_m19_ccf_axis_parallel_shortedge_design_points.csv`
- MMF 관련 파일들

삭제하지 않은 MMF 관련 파일:

- `analyze_v_ipm_m19_current_only_mmf_check_codex.m`
- `run_analyze_v_ipm_m19_current_only_mmf_check_interactive_codex.cmd`
- `run_analyze_v_ipm_m19_current_only_mmf_check_interactive_codex.log`

## 다음 사람이 바로 할 일

1. VM MATLAB에서 `analyze_axis_shortedge_ccf`를 다시 실행한다.
2. 만약 또 에러가 나면 먼저 `progress_log.txt` 생성 여부와 에러 줄 번호를 확인한다.
3. 해석이 정상 진행되면 결과 폴더 `femm_output_v_ipm_m19_axis_shortedge_ccf` 아래의 summary CSV와 partial MAT를 회수한다.
4. 완료 후 평균토크, 토크리플, 코깅토크, 최대 radial force 기준으로 최적 설계 후보를 추린다.

## 최우선 주의사항

- 사용자가 집에 없을 때 `matlab.exe`를 절대 종료하지 않는다.
- MATLAB Desktop 안에서 `codex_matlab_job_daemon`이 실행되므로 `matlab.exe`를 종료하면 데몬도 같이 죽는다.
- `femm.exe`만 종료해도 현재 케이스만 실패하고 다음 케이스로 넘어갈 수 있으므로 안전한 작업 중지 방법이 아니다.
- 현재 runner에는 안전한 취소 기능이 없다. 다음 장기 해석 전에 `cancel flag` 기능부터 구현한다.
- VM 재부팅, MATLAB 종료, 프로세스 강제 종료는 사용자의 명시적 확인 없이는 하지 않는다.

## 현재 시스템 상태

- Windows VM SSH: `dohyun@192.168.195.129`
- Windows MATLAB 폴더: `C:\Users\dohyu\Documents\MATLAB\spm`
- Mac 작업 폴더: `/Users/dohyunkim/Documents/Window`
- SSH는 2026-07-18 마지막 확인 시 정상 접속됐다.
- `matlab.exe`는 실행 중이지만 MATLAB job daemon heartbeat는 2026-07-19 23:31에서 멈춰 있다.
- 따라서 원격 작업 큐는 현재 비활성이다.
- `codex_matlab_job_daemon.m` 파일은 삭제되지 않았고 VM에 그대로 있다.
- 대기 중이던 정밀 오프셋 요청 파일 `codex_job_request.txt`는 삭제됐다.
- 기존 FEMM/MATLAB 결과 파일은 삭제하지 않았다.

## 데몬 복구 방법

사용자가 VMware 화면에 접근할 수 있을 때 Windows에서 MATLAB Desktop을 열고 MATLAB 명령창에 입력한다.

```matlab
cd('C:\Users\dohyu\Documents\MATLAB\spm');
codex_matlab_job_daemon
```

명령창에 `watching` 상태가 표시되면 원격 작업 큐를 다시 사용할 수 있다.

중요:

- SSH에서 새 MATLAB을 실행하는 방식은 FEMM GUI/COM 연동이 불안정했다.
- 현재 검증된 방식은 사용자가 연 MATLAB Desktop 안에서 데몬을 실행하는 방식이다.
- 데몬이 복구되기 전에는 원격 FEMM 해석을 새로 시작하지 않는다.

## 이번에 확정된 권선 문제와 수정 결과

기존 권선 배열은 다음과 같았다.

```text
AAAB'B'B'CCCA'A'A'BBBC'C'C'
```

공극 자속밀도 공간고조파 분석 결과 기존 배열은 사실상 2극 자계를 만들었다.

```text
기존 2극 성분 n=1: 약 1.096 T
기존 4극 성분 n=2: 약 0.0006 T
```

18슬롯 / 4극 / 3상 싱글레이어 권선표를 적용한 새 배열은 다음과 같다.

```text
슬롯:  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18
권선:  A  A C' A' B A' C  C B' C' A C' B  B A' B' C B'
```

연속 표기:

```text
AAC'A'BA'CCB'C'AC'BBA'B'CB'
```

새 배열의 FEMM 검증 결과:

```text
4극 성분 n=2 평균: 1.216 T
잔류 2극 성분 n=1 평균: 0.234 T
4극/2극 비율: 5.19
자계축 기울기: 0.5029 mech/elec
이론 기울기: 0.5000 mech/elec
성공 케이스: 12/12
```

따라서 새 배열은 정상적인 4극 회전자계를 만든다.

수정 후 VM에 업로드된 공용 파일:

- `generate_v_ipm_motor.m`
- `run_v_ipm_m19_torque_sweep_codex.m`
- `analyze_v_ipm_m19_current_only_airgap_axis_codex.m`

검증 플롯:

- `/Users/dohyunkim/Documents/Window/v_ipm_m19_4pole_winding_validation.png`

검증 MAT:

- `/Users/dohyunkim/Documents/Window/v_ipm_m19_current_only_airgap_axis_4pole_sl_codex.mat`

## 새 권선 커뮤테이션 탐색 결과

로터 기계각을 `0 deg`로 고정하고 10 A 전류의 전기각을 스윕했다.

완료된 주요 결과:

```text
전기각 40 deg: 30.452 N.m
전기각 50 deg: 35.619 N.m
전기각 60 deg: 37.469 N.m  <- 양의 최대 후보
전기각 70 deg: 36.012 N.m
전기각 80 deg: 31.882 N.m
전기각 160 deg: -36.843 N.m
```

현재 채택할 커뮤테이션 값:

```text
전류 전기각 오프셋: 60 deg
run_v_ipm 코드의 commutation_offset_deg: 30 deg mechanical
관계: electrical offset = pole_pairs(2) * mechanical offset
```

주의:

- `37.469 N.m`는 로터 0도 고정 상태의 정토크다.
- 최종 평균 토크가 아니며, 로터 회전 동기 해석이 필요하다.
- 거친 스윕은 강제 종료 전에 일부 케이스까지 저장됐다.
- `270 deg` 케이스에서 FEMM `Couldn't write to specified file` 오류가 발생한 기록이 있다.
- 정밀 오프셋 탐색은 취소했고 더 진행하지 않는다.

부분 결과:

- `/Users/dohyunkim/Documents/Window/v_ipm_4pole_comm_coarse_partial.mat`

## 다음에 반드시 먼저 구현할 것: 안전 취소

장기 해석을 다시 시작하기 전에 다음 기능을 추가한다.

1. `run_v_ipm_m19_torque_sweep_codex.m`이 각 케이스 시작 전에 `codex_job_cancel.txt` 존재 여부를 확인한다.
2. cancel 파일이 있으면 partial MAT를 저장하고 현재 sweep만 정상 종료한다.
3. `codex_matlab_job_daemon.m`은 종료하지 않고 다시 `watching` 상태로 돌아간다.
4. 취소 처리 후 `codex_job_cancel.txt`를 삭제하거나 완료 상태로 변경한다.
5. 이후에는 `taskkill matlab.exe`를 작업 중지 수단으로 사용하지 않는다.

## 데몬 복구 후 실행할 해석

준비된 파일:

- `/Users/dohyunkim/Documents/Window/analyze_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex.m`
- 같은 파일이 Windows VM의 MATLAB 폴더에도 업로드돼 있다.

설정:

```text
권선: AAC'A'BA'CCB'C'AC'BBA'B'CB'
Imax: 10 A
전류 전기각 오프셋: 60 deg
코드 기계각 오프셋: 30 deg
로터 기계각: 0:1:360 deg
총 케이스: 361
```

예상 실행 시간은 케이스당 약 50~60초 기준으로 5~6시간이다.

안전 취소 기능을 구현하고 데몬이 복구된 뒤 작업 큐에 넣을 명령:

```text
clear run_v_ipm_m19_torque_sweep_codex analyze_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex; analyze_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex
```

원격 큐 파일:

```text
C:\Users\dohyu\Documents\MATLAB\spm\codex_job_request.txt
```

출력 폴더:

```text
C:\Users\dohyu\Documents\MATLAB\spm\femm_output_v_ipm_m19_4pole_loaded_rotation_elec60_10A_codex
```

## 다음 작업 순서

1. 사용자가 VMware에서 MATLAB Desktop과 `codex_matlab_job_daemon`을 다시 실행한다.
2. 원격에서 heartbeat와 `watching` 상태만 확인한다.
3. 안전 취소 플래그 기능을 runner와 daemon에 구현하고 VM에 업로드한다.
4. 짧은 2~3케이스 시험으로 cancel 기능과 4극 권선 캐시 반영을 확인한다.
5. 전기각 오프셋 60도, 10 A, 기계각 0~360도 회전 해석을 시작한다.
6. 실행 중에는 MATLAB 프로세스를 절대 종료하지 않는다.
7. 완료 후 평균 토크, 최소/최대 토크, peak-to-peak 및 토크리플을 플롯한다.

## 후속 분석: 균일 에어갭 민감도

편심은 분석하지 않는다. 로터와 스테이터 중심은 일치시킨 상태에서 균일한 에어갭 길이 하나만 변경한다.

입력변수:

```text
X = 균일 에어갭 길이 g [mm]
g = Core_ri - (PM_r + Seal)
```

에어갭 이외의 형상, 전류, 커뮤테이션 오프셋은 모두 고정한다.

첫 분석의 출력변수:

```text
Y1 = 평균 토크 [N.m]
Y2 = 토크리플 [%] = (Tmax - Tmin) / abs(Tmean) * 100
Y3 = 무부하 코깅토크 peak-to-peak [N.m]
Y4 = 최대 radial force 크기 [N]
```

radial force는 `Fx` 또는 `Fy`의 평균을 사용하지 않는다. 방향 때문에 상쇄될 수 있으므로 각 회전각에서 힘의 크기를 계산한다.

```text
Fr(theta) = sqrt(Fx(theta)^2 + Fy(theta)^2)
Y4 = max(Fr(theta))
```

필요하면 보조 출력으로 `mean(Fr)`와 radial force ripple도 함께 저장한다.

처음에는 기준 에어갭 주변을 최소 5점으로 해석한다. 실제 범위는 제작 가능한 치수와 현재 기준값을 확인한 뒤 확정한다.

예시:

```text
g = 0.3, 0.4, 0.5, 0.6, 0.7 mm
```

단순 그래프로 출력 경향을 확인하고, 기준 에어갭 `g0` 주변의 기울기와 정규화 민감도를 계산한다.

```text
절대 민감도      = dY/dg
정규화 민감도 S = (g0 / Y0) * (dY/dg)
```

정규화 민감도 `S`는 에어갭이 1% 변할 때 해당 출력이 대략 몇 % 변하는지를 나타낸다. 부호는 증가/감소 방향을 의미한다.

코깅토크는 전류 `0 A`의 별도 무부하 해석에서 계산하고, 평균 토크·토크리플·radial force는 확정된 전류와 커뮤테이션 조건의 부하 해석에서 계산한다.

이 분석은 입력변수 하나에 대한 정식 1변수 민감도 분석이다. 이후 V각도, 자석 두께 등 형상변수를 추가하면 다변수 민감도 분석으로 확장한다.

## 2026-07-20 완료 결과와 에어갭 최적화 준비

4극 권선, 10 A, 전기각 오프셋 60도 조건의 0:1:360도 해석이 361/361 성공했다.

```text
평균 토크: 37.06395 N.m
최소 토크: 32.86558 N.m
최대 토크: 41.22737 N.m
토크 peak-to-peak: 8.36179 N.m
토크리플: 22.56044 %
```

토크 FFT의 지배 성분은 기계각 1회전당 12차이며, 4극 모터의 6차 전기각 토크리플과 일치한다.

에어갭 5점 민감도 실행 파일을 작성하고 VM에 업로드했다.

- `analyze_v_ipm_m19_airgap_sensitivity_5point_codex.m`
- 에어갭: `0.5, 0.6, 0.7, 0.8, 0.9 mm`
- 스테이터 내경은 `64.0 mm`로 고정하고 로터 외경만 `63.0, 62.8, 62.6, 62.4, 62.2 mm`로 줄인다.
- 구현식: `Seal = Core_ri - gap - PM_r`; 자석 위치와 스테이터 형상은 고정되고 로터 외주 철심 두께가 변한다.
- 부하: `10 A`, 전기각 오프셋 `60 deg`, 기계각 `0:2:28 deg`
- 코깅: `0 A`, 기계각 `0:1:9 deg`
- 총 FEMM 케이스: `5 * (15 + 10) = 125`
- 알려진 부하 토크 30도 주기와 코깅 10도 주기를 사용해 계산량을 줄였다.
- 각 케이스 후 `.fem/.ans/.node/.ele/.edge/.poly/.pbc`를 자동 삭제하도록 `keep_femm_files=false`를 추가했다.
- 결과는 MAT와 CSV로 보존한다.

실행 명령:

```matlab
cd('C:\Users\dohyu\Documents\MATLAB\spm');
clear run_v_ipm_m19_torque_sweep_codex default_v_ipm_m19_settings_codex;
analyze_v_ipm_m19_airgap_sensitivity_5point_codex
```

출력 폴더:

```text
C:\Users\dohyu\Documents\MATLAB\spm\femm_output_v_ipm_m19_airgap_rotor_shrink_05_09_codex
```

자동 실행 시도 결과:

- SSH 세션의 `AppActivate`는 콘솔 MATLAB 세션에 접근하지 못해 입력 없이 안전하게 실패했다.
- 로그인 토큰 예약 작업도 사용자 세션 진입 전에 대기해 폐기했다.
- `vmrun -interactive`는 VM 암호화 암호와 Windows 로그인 암호가 달라 실행하지 못했다.
- MATLAB/FEMM 프로세스는 종료하지 않았다.
- 데몬이 다시 `watching` 상태가 되면 작업 큐로 위 명령을 실행할 수 있다.

## 2026-07-20 에어갭 스윕 오류와 최종 수정

첫 에어갭 스크립트는 `g = 0.3:0.1:0.7 mm`로 작성됐다. 스테이터 내경을 고정한 상태에서 `g=0.3 mm`를 만들기 위해 기준 로터 외경 `63.0 mm`를 `63.4 mm`로 키웠고, 기존 스테이터 치선과 형상이 겹쳤다.

발생한 FEMM 오류:

```text
Material properties have not been defined for all regions
COMPLETE completed=0 failed=15 mean_torque=NaN
Unable to perform assignment because the left and right sides have a different number of elements.
```

두 번째 MATLAB 오류는 FEMM 15케이스가 모두 실패한 뒤 빈 토크 배열에 `min/max`를 적용하면서 발생한 후속 오류다.

최종 수정 사항:

```text
스테이터 내경: 64.0 mm 고정
에어갭:       0.5, 0.6, 0.7, 0.8, 0.9 mm
로터 외경:   63.0, 62.8, 62.6, 62.4, 62.2 mm
```

- 기준 형상부터 로터 외경을 줄이는 방향으로만 스윕한다.
- 구현식은 `Seal = Core_ri - gap - PM_r`이다.
- 자석 위치, 스테이터 형상, 스테이터 내경은 고정한다.
- 로터 외주 철심 두께만 감소한다.
- 부하 케이스가 전부 실패하면 빈 배열을 계산하지 않고 해당 에어갭을 건너뛴다.
- 코깅 케이스가 전부 실패할 때도 동일하게 안전하게 건너뛴다.
- 이전 실패 결과와 섞이지 않도록 새 출력 폴더를 사용한다.

수정 파일은 Windows VM에 업로드 완료됐다.

```text
C:\Users\dohyu\Documents\MATLAB\spm\analyze_v_ipm_m19_airgap_sensitivity_5point_codex.m
```

새 출력 폴더:

```text
C:\Users\dohyu\Documents\MATLAB\spm\femm_output_v_ipm_m19_airgap_rotor_shrink_05_09_codex
```

다음 실행:

```matlab
cd('C:\Users\dohyu\Documents\MATLAB\spm');
clear run_v_ipm_m19_torque_sweep_codex default_v_ipm_m19_settings_codex;
analyze_v_ipm_m19_airgap_sensitivity_5point_codex
```

현재 사용자가 MATLAB Desktop에서 직접 실행하기로 했다. 실행 전후로 MATLAB 프로세스를 원격에서 종료하지 않는다. 결과가 완료되면 `airgap_sensitivity_result.mat`과 `airgap_sensitivity_summary.csv`를 가져와 평균 토크, 토크리플, 코깅토크 경향을 플롯한다. `force_max_N`은 저장하지만 force 계산 검증 전에는 최적 설계의 주 목적함수로 사용하지 않는다.
에어갭 결과 메모:

- `g = 0.5 ~ 0.9 mm` 범위에서 평균 토크는 거의 선형적으로 감소했다.
- 선형 적합:

```text
T_mean ~= 39.5902 - 5.0017 * g(mm)
R^2 = 0.99894
```

- 현재 범위에서는 `airgap 증가 -> 공극 자기저항 증가 -> 자속 감소 -> 평균 토크 감소` 경향이 FEMM 결과와 잘 부합한다.
- 다만 이 경향은 현재 공극 범위에 대한 국소 해석이며, 더 넓은 범위에서는 포화와 누설자속 때문에 비선형성이 커질 수 있다.
