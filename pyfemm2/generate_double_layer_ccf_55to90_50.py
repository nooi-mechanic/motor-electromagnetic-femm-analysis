"""Generate a separate 50-point double-layer CCF with V angle 55–90 deg."""

from pathlib import Path

import generate_double_layer_ccf_50 as study


ROOT = Path(__file__).resolve().parent
study.OUTPUT_DIR = ROOT / "double_layer_ccf_55to90_50_previews"
study.FEM_DIR = study.OUTPUT_DIR / "fem"
study.DESIGN_CSV = study.OUTPUT_DIR / "double_layer_ccf_4factor_55to90_50.csv"
study.SEED = 20260802
study.RANGES["v_angle_deg"] = (55.0, 90.0)


if __name__ == "__main__":
    study.main()
