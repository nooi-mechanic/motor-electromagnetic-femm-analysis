"""Build the post-processing notebook for the matched-pair FEMM experiment."""

from pathlib import Path
import nbformat as nbf


ROOT = Path(__file__).resolve().parent
OUT = ROOT / "analysis_results" / "inner_angle_ripple_physics_report.ipynb"


def md(source):
    return nbf.v4.new_markdown_cell(source.strip())


def code(source):
    return nbf.v4.new_code_cell(source.strip())


nb = nbf.v4.new_notebook()
nb.metadata.kernelspec = {"display_name": "Python 3", "language": "python", "name": "python3"}
nb.cells = [
    md(r"""
# Inner V-angle and torque-ripple physical validation

This report compares a low-ripple/high-ripple pair selected from the independent-angle Sobol 64
population. Magnet usage is matched as closely as the existing DOE permits; torque per magnet area,
ripple, air-gap flux, and Maxwell stress are then compared. Other geometry variables are not identical,
so this is a whole-rotor performance comparison rather than an inner-angle-only causal experiment.

Analysis chain:

$$
\text{Inner angle}\rightarrow B_r(\theta)\text{ harmonics}
\rightarrow \frac{B_rB_t}{\mu_0}\text{ variation}
\rightarrow \text{torque ripple}
$$
"""),
    code(r"""
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from IPython.display import display, Image

ROOT = Path.cwd().resolve()
if ROOT.name == 'analysis_results':
    ROOT = ROOT.parent
EXP = ROOT / 'inner_angle_ripple_physics_experiment'
PLAN = pd.read_csv(EXP / 'matched_pair_plan.csv')
display(PLAN[[
    'case_label', 'run', 'inner_angle_deg', 'outer_angle_deg',
    'loaded_torque_mean_Nm', 'loaded_torque_ripple_pct', 'total_magnet_area_mm2'
]].round(4))
display(Image(filename=str(EXP / 'matched_pair_geometry_preview.png')))
"""),
    md("## 1. FEMM completion check"),
    code(r"""
case_dirs = {
    row.case_label: EXP / f"{row.case_label}_run_{int(row.run):03d}"
    for _, row in PLAN.iterrows()
}
required = ['torque_sweep.csv', 'airgap_field_and_maxwell_stress.csv', 'FEMM_COMPLETE.json']
status = pd.DataFrame({
    label: {name: (folder / name).exists() for name in required}
    for label, folder in case_dirs.items()
}).T
display(status)
READY = bool(status.to_numpy().all())
if not READY:
    print('FEMM results are not present yet. Run later:')
    print(r'.\.venv\Scripts\python.exe .\run_inner_angle_ripple_physics_experiment.py --run-femm')
"""),
    md("## 2. Loaded torque waveform and FFT"),
    code(r"""
if READY:
    torque = {
        label: pd.read_csv(folder / 'torque_sweep.csv').query("state == 'loaded'")
        for label, folder in case_dirs.items()
    }
    fig, axes = plt.subplots(1, 2, figsize=(13, 4.7), constrained_layout=True)
    styles = {
        'low_ripple': dict(color='#1f77b4', marker='o'),
        'high_ripple': dict(color='#d62728', marker='s'),
    }
    for case_index, (label, data) in enumerate(torque.items()):
        style = styles[label]
        axes[0].plot(data.theta_deg, data.torque_Nm, '-', color=style['color'],
                     marker=style['marker'], label=label)
        centered = data.torque_Nm.to_numpy() - data.torque_Nm.mean()
        amplitude = 2 * np.abs(np.fft.rfft(centered)) / len(centered)
        order = np.arange(len(amplitude))
        markerline, stemlines, baseline = axes[1].stem(
            order[1:] + (-0.10 if case_index == 0 else 0.10), amplitude[1:],
            label=label, basefmt=' '
        )
        plt.setp(markerline, marker=style['marker'], color=style['color'], markersize=6)
        plt.setp(stemlines, color=style['color'], linewidth=1.7, alpha=.85)
    axes[0].set(xlabel='Rotor mechanical angle [deg]', ylabel='Torque [N*m]', title='Loaded torque waveform')
    axes[1].set(xlabel='FFT bin over sampled mechanical period', ylabel='Amplitude [N*m]', title='Torque-ripple spectrum')
    for ax in axes: ax.grid(alpha=.25); ax.legend()
"""),
    md("## 3. No-load air-gap radial flux density and spatial FFT"),
    code(r"""
if READY:
    fields = {label: pd.read_csv(folder / 'airgap_field_and_maxwell_stress.csv') for label, folder in case_dirs.items()}
    fig, axes = plt.subplots(1, 2, figsize=(14, 4.8), constrained_layout=True)
    harmonic_rows = []
    for case_index, (label, data) in enumerate(fields.items()):
        style = styles[label]
        no_load = data.query("state == 'no_load'").drop_duplicates('airgap_angle_deg').sort_values('airgap_angle_deg')
        # Remove duplicated 360-degree endpoint for FFT.
        no_load = no_load.loc[no_load.airgap_angle_deg < 360]
        axes[0].plot(no_load.airgap_angle_deg, no_load.Br_T,
                     color=style['color'], label=label)
        signal = no_load.Br_T.to_numpy() - no_load.Br_T.mean()
        amp = 2 * np.abs(np.fft.rfft(signal)) / len(signal)
        orders = np.arange(len(amp))
        markerline, stemlines, baseline = axes[1].stem(
            orders[1:21] + (-0.10 if case_index == 0 else 0.10), amp[1:21],
            label=label, basefmt=' '
        )
        plt.setp(markerline, marker=style['marker'], color=style['color'], markersize=6)
        plt.setp(stemlines, color=style['color'], linewidth=1.7, alpha=.85)
        harmonic_rows.extend({'case': label, 'spatial_order_per_rev': int(k), 'Br_amplitude_T': amp[k]} for k in range(1, min(21, len(amp))))
    axes[0].set(xlabel='Mechanical angle around air gap [deg]', ylabel='Br [T]', title='No-load air-gap radial flux density')
    axes[1].set(xlabel='Spatial harmonic order per mechanical revolution', ylabel='Br amplitude [T]', title='No-load Br spatial FFT')
    for ax in axes: ax.grid(alpha=.25); ax.legend()
    harmonics = pd.DataFrame(harmonic_rows)
    display(harmonics.pivot(index='spatial_order_per_rev', columns='case', values='Br_amplitude_T').round(5))
"""),
    md(r"""
## 4. Loaded Maxwell shear-stress distribution

The sampled air-gap proxy is

$$
\tau_t(\theta)=\frac{B_r(\theta)B_t(\theta)}{\mu_0}.
$$

Its spatial nonuniformity is compared at identical current and commutation conditions. This is a
local air-gap stress proxy; the FEMM block-integral torque remains the reference total torque.
"""),
    code(r"""
if READY:
    fig, axes = plt.subplots(1, 2, figsize=(14, 4.8), constrained_layout=True)
    stress_stats = []
    for label, data in fields.items():
        loaded = data.query("state == 'loaded'")
        mean_by_angle = loaded.groupby('airgap_angle_deg', as_index=False).maxwell_shear_Pa.mean()
        axes[0].plot(mean_by_angle.airgap_angle_deg, mean_by_angle.maxwell_shear_Pa / 1e3, label=label)
        rms_by_theta = loaded.groupby('theta_deg').maxwell_shear_Pa.apply(lambda x: np.sqrt(np.mean(np.square(x))))
        axes[1].plot(rms_by_theta.index, rms_by_theta.values / 1e3, 'o-', label=label)
        stress_stats.append({
            'case': label,
            'spatial_std_kPa': mean_by_angle.maxwell_shear_Pa.std(ddof=0) / 1e3,
            'theta_rms_variation_kPa': rms_by_theta.std(ddof=0) / 1e3,
        })
    axes[0].set(xlabel='Air-gap angle [deg]', ylabel='Mean shear stress [kPa]', title='Loaded mean Maxwell shear distribution')
    axes[1].set(xlabel='Rotor mechanical angle [deg]', ylabel='Spatial RMS shear stress [kPa]', title='Stress variation with rotor position')
    for ax in axes: ax.grid(alpha=.25); ax.legend()
    display(pd.DataFrame(stress_stats).set_index('case').round(4))
"""),
    md("## 5. Quantitative evidence chain"),
    code(r"""
if READY:
    evidence_rows = []
    fft_store = {}
    for label in case_dirs:
        plan_row = PLAN.loc[PLAN.case_label == label].iloc[0]
        magnet_area = float(plan_row.total_magnet_area_mm2)
        t = torque[label].sort_values('theta_deg')
        torque_mean = t.torque_Nm.mean()
        torque_pkpk = t.torque_Nm.max() - t.torque_Nm.min()
        torque_ripple = 100 * torque_pkpk / abs(torque_mean)

        no_load = fields[label].query("state == 'no_load'").drop_duplicates('airgap_angle_deg').sort_values('airgap_angle_deg')
        no_load = no_load.loc[no_load.airgap_angle_deg < 360]
        br = no_load.Br_T.to_numpy() - no_load.Br_T.mean()
        br_amp = 2 * np.abs(np.fft.rfft(br)) / len(br)
        fft_store[label] = br_amp

        loaded = fields[label].query("state == 'loaded'")
        shear_spatial_rms = loaded.groupby('theta_deg').maxwell_shear_Pa.apply(
            lambda x: np.sqrt(np.mean(np.square(x)))
        )
        pressure_spatial_rms = loaded.groupby('theta_deg').maxwell_radial_pressure_Pa.apply(
            lambda x: np.sqrt(np.mean(np.square(x)))
        )
        evidence_rows.append({
            'case': label,
            'total_magnet_area_mm2': magnet_area,
            'mean_torque_Nm': torque_mean,
            'torque_per_magnet_area_Nm_per_mm2': torque_mean / magnet_area,
            'torque_pkpk_Nm': torque_pkpk,
            'torque_pkpk_per_magnet_area_Nm_per_mm2': torque_pkpk / magnet_area,
            'torque_ripple_pct': torque_ripple,
            'Br_fundamental_order2_T': br_amp[2],
            'Br_fundamental_per_magnet_area_T_per_mm2': br_amp[2] / magnet_area,
            'Br_total_harmonic_rms_order3plus_T': np.sqrt(np.sum(br_amp[3:21]**2)),
            'Br_harmonic_rms_per_magnet_area_T_per_mm2': np.sqrt(np.sum(br_amp[3:21]**2)) / magnet_area,
            'shear_spatial_RMS_theta_std_kPa': shear_spatial_rms.std(ddof=0) / 1e3,
            'radial_pressure_RMS_theta_std_kPa': pressure_spatial_rms.std(ddof=0) / 1e3,
        })
    evidence = pd.DataFrame(evidence_rows).set_index('case')
    display(evidence.round(5))

    harmonic_comparison = pd.DataFrame({
        'spatial_order': np.arange(1, 21),
        'low_ripple_T': fft_store['low_ripple'][1:21],
        'high_ripple_T': fft_store['high_ripple'][1:21],
    })
    harmonic_comparison['high_minus_low_T'] = harmonic_comparison.high_ripple_T - harmonic_comparison.low_ripple_T
    harmonic_comparison['abs_difference_T'] = harmonic_comparison.high_minus_low_T.abs()
    print('Spatial harmonics with the largest low/high difference:')
    display(harmonic_comparison.nlargest(10, 'abs_difference_T').round(6))

    low, high = evidence.loc['low_ripple'], evidence.loc['high_ripple']
    normalized_comparison = pd.Series({
        'magnet_area_difference_pct_high_vs_low': 100 * (high.total_magnet_area_mm2 / low.total_magnet_area_mm2 - 1),
        'mean_torque_difference_pct_high_vs_low': 100 * (high.mean_torque_Nm / low.mean_torque_Nm - 1),
        'torque_density_difference_pct_high_vs_low': 100 * (high.torque_per_magnet_area_Nm_per_mm2 / low.torque_per_magnet_area_Nm_per_mm2 - 1),
        'ripple_difference_pctpoint_high_minus_low': high.torque_ripple_pct - low.torque_ripple_pct,
        'Br_fundamental_per_area_difference_pct': 100 * (high.Br_fundamental_per_magnet_area_T_per_mm2 / low.Br_fundamental_per_magnet_area_T_per_mm2 - 1),
        'Br_harmonic_RMS_per_area_difference_pct': 100 * (high.Br_harmonic_rms_per_magnet_area_T_per_mm2 / low.Br_harmonic_rms_per_magnet_area_T_per_mm2 - 1),
    })
    print('Magnet-usage-normalized comparison:')
    display(normalized_comparison.to_frame('value').round(4))
    checks = pd.Series({
        'rerun_preserves_high_ripple_label': high.torque_ripple_pct > low.torque_ripple_pct,
        'high_case_has_larger_Br_harmonic_RMS': high.Br_total_harmonic_rms_order3plus_T > low.Br_total_harmonic_rms_order3plus_T,
        'high_case_has_larger_shear_variation': high.shear_spatial_RMS_theta_std_kPa > low.shear_spatial_RMS_theta_std_kPa,
        'high_case_has_larger_radial_pressure_variation': high.radial_pressure_RMS_theta_std_kPa > low.radial_pressure_RMS_theta_std_kPa,
    })
    display(checks.to_frame('supported'))
    support_count = int(checks.sum())
    print(f'Evidence-chain checks supported: {support_count}/{len(checks)}')
    if support_count == len(checks):
        print('Conclusion: at nearly matched magnet usage, the rerun consistently supports an air-gap-field / Maxwell-stress explanation of the torque-density and ripple differences.')
    elif checks.iloc[0] and checks.iloc[2]:
        print('Conclusion: torque and tangential-stress variation support the mechanism, but the Br harmonic or radial-pressure evidence is mixed. Do not claim a single harmonic as the sole cause.')
    else:
        print('Conclusion: the current matched-pair rerun does not yet establish a consistent electromagnetic explanation; refine the comparison or sampling.')
"""),
    md(r"""
## 6. Interpretation checklist

- Do the two cases retain a large ripple difference after rerun?
- Which $B_r$ spatial harmonics differ most strongly?
- Do those changes coincide with torque-spectrum components rather than only increasing peak $B_r$?
- Does the high-ripple case show stronger spatial/rotor-position variation in $B_rB_t/\mu_0$?
- Are local bridge/tip flux-density concentrations visible in the saved FEMM B-magnitude images?

A causal statement should be made only when the geometry change, air-gap harmonic change, Maxwell
stress variation, and torque-ripple change form a consistent chain.
"""),
]

OUT.parent.mkdir(exist_ok=True)
nbf.write(nb, OUT)
print(f"Created: {OUT}")
