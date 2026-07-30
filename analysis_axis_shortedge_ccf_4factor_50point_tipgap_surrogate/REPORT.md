# Surrogate 1000-candidate Pareto report

- Training samples: 50
- Surrogate: RandomForestRegressor per target
- Candidate generation: 1000-point Latin hypercube inside measured bounds

## 5-fold CV R2
- loaded_torque_mean: 0.630
- loaded_torque_ripple_pct: 0.754
- cogging_torque_pkpk: 0.489
- loaded_force_max: 0.631

## Predicted Pareto count
- 3 points

## Top predicted Pareto points
|   magnet_thickness_mm |   magnet_length_mm |   v_angle_deg |   tip_gap_mm |   loaded_torque_mean |   loaded_torque_ripple_pct |   cogging_torque_pkpk |
|----------------------:|-------------------:|--------------:|-------------:|---------------------:|---------------------------:|----------------------:|
|               5.41226 |            16.7645 |       64.0316 |     0.551069 |              46.0139 |                    19.6689 |             0.0999025 |
|               5.29078 |            16.7115 |       63.0358 |     4.01694  |              43.1847 |                    19.5514 |             0.104952  |
|               4.58594 |            16.5794 |       62.8755 |     3.91337  |              42.4313 |                    19.5306 |             0.0993852 |
