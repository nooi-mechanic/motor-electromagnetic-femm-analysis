# Radial vs. 3-segment Halbach outer-rotor motor

This report bundle compares radial and three-segment quasi-Halbach magnet arrays in a 36-slot, 30-pole outer-rotor Hairpin PMSM using nonlinear 2D FEMM magnetostatic analysis.

## Main report

- `radial_vs_halbach_comprehensive_report.ipynb`

The notebook contains the executed tables, plots, and embedded FEMM field screenshots. It covers:

- no-load and 1 A baseline flux/torque;
- 1–15 A initial saturation screening;
- 15 A fine rotor-position torque sweep;
- integrated 0–50 A current/position analysis;
- radial-versus-Halbach leakage and steel-flux comparison;
- 2.5 mm half-yoke experiment;
- 1.50–5.00 mm rotor back-iron sweep;
- full-position validation of boundary thickness candidates.

## Directory layout

- `outer_rotor_36s30p_hairpin/`: CSV inputs used directly by the notebook and source PNG captures.
- `models/`: representative radial, Halbach, and 2.5 mm back-iron FEMM models.
- `scripts/`: analysis and sweep scripts used to generate the report data.

The notebook resolves `outer_rotor_36s30p_hairpin` relative to its own working directory. Open Jupyter in this directory, or set this directory as the notebook working directory, to rerun every cell.

## Scope and limitations

The results are magnetostatic and current-driven. They do not directly include inverter voltage limits, speed-dependent back-EMF, iron loss, copper loss, magnet eddy-current loss, thermal rise, demagnetization, or rotor mechanical stress.

Large FEMM `.ans` solution files are intentionally excluded from Git because each solution is tens of megabytes and the report already contains the derived data and plots. The included `.fem` files can be solved again with FEMM/pyFEMM.

The 1.6 T P99 and 1.7 T maximum lines shown in the report are engineering reference lines, not absolute pass/fail limits. The final thickness must be selected with the actual steel B-H/loss data, thermal duty, manufacturing tolerance, and structural safety margin.
