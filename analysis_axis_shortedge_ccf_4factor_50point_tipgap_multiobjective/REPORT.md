# Multiobjective pair analysis

- Measured designs: 50
- Surrogate candidates: 1000

## Magnet usage model
- One magnet piece area = `length * thickness * sin(v_angle)`
- Total rotor magnet area = `8 * piece area`

## loaded_torque_mean vs total_magnet_area_mm2
- Measured Pareto count: 11
- Best-front run: 311, torque=53.544, ripple=19.686, cogging=0.0786, force=713.1, magnet_area=635.9

## loaded_torque_mean vs cogging_torque_pkpk
- Measured Pareto count: 7
- Best-front run: 311, torque=53.544, ripple=19.686, cogging=0.0786, force=713.1, magnet_area=635.9

## loaded_torque_mean vs loaded_force_max
- Measured Pareto count: 2
- Best-front run: 311, torque=53.544, ripple=19.686, cogging=0.0786, force=713.1, magnet_area=635.9

## loaded_torque_mean vs loaded_torque_ripple_pct
- Measured Pareto count: 3
- Best-front run: 311, torque=53.544, ripple=19.686, cogging=0.0786, force=713.1, magnet_area=635.9
