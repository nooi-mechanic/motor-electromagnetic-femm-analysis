"""Prepare the five DNN-selected double-layer designs for FEMM validation."""

from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "double_layer_55to90_dnn_candidates_10000.csv"
OUTPUT_DIR = ROOT / "double_layer_55to90_femm_validation_5"
DESIGN_CSV = OUTPUT_DIR / "double_layer_validation_5_designs.csv"
SELECTED = [6038, 4325, 5983, 4791, 9439]
PURPOSE = {
    6038: "maximum_torque",
    4325: "minimum_magnet_balanced",
    5983: "torque_ripple_balance",
    4791: "torque_ripple_balance_alternative",
    9439: "minimum_ripple",
}


def main() -> None:
    candidates = pd.read_csv(SOURCE)
    selected = candidates[candidates["candidate"].isin(SELECTED)].copy()
    selected = selected.set_index("candidate").loc[SELECTED].reset_index()
    selected = selected.drop(columns=["run"], errors="ignore")
    selected.insert(0, "run", range(1, len(selected) + 1))
    selected["selection_purpose"] = selected["candidate"].map(PURPOSE)

    OUTPUT_DIR.mkdir(exist_ok=True)
    selected.to_csv(DESIGN_CSV, index=False, encoding="utf-8-sig")
    print(f"Created: {DESIGN_CSV}")
    print(
        selected[
            [
                "run", "candidate", "selection_purpose",
                "total_thickness_mm", "inner_length_mm",
                "v_angle_deg", "layer_normal_gap_mm",
                "pred_mean_torque_Nm", "pred_ripple_pkpk_Nm",
            ]
        ].to_string(index=False)
    )


if __name__ == "__main__":
    main()
