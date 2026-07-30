# MATLAB/FEMM VM Sources

Snapshot date: 2026-07-29

This directory contains the source and design-point files copied from:

```text
C:\Users\dohyu\Documents\MATLAB\spm
```

Included file types:

- MATLAB analysis and geometry scripts (`.m`)
- Windows launch and queue helpers (`.ps1`, `.cmd`)
- Design-point tables (`.csv`)

Generated FEMM models, solver outputs, MAT result files, logs, lock files and
credentials are intentionally excluded.

## Environment

- Windows VM
- MATLAB R2024a
- FEMM 4.2 MATLAB interface

The reliable remote workflow uses an already-open MATLAB Desktop session:

```matlab
cd('C:\Users\dohyu\Documents\MATLAB\spm');
codex_matlab_job_daemon
```

After the daemon starts, submit one MATLAB command through
`codex_job_request.txt`. See `../docs/NEXT_STEPS_FEMM_MATLAB.md` for the
complete queue, monitoring and safe-cancellation procedure.

## Important Entry Points

- `generate_v_ipm_motor.m`: baseline V-IPM geometry
- `run_v_ipm_m19_torque_sweep_codex.m`: reusable torque sweep runner
- `analyze_v_ipm_m19_airgap_sensitivity_5point_codex.m`: air-gap sensitivity
- `analyze_axis_shortedge_ccf.m`: axis-short-edge magnet CCF analysis
- `codex_matlab_job_daemon.m`: file-driven remote MATLAB job daemon

Some older scripts are retained as experiment history and may contain fixed
VM paths. Check settings, output paths and geometry clearance with a short
single-case run before starting a long sweep.
