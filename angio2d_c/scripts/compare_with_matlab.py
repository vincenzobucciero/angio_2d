#!/usr/bin/env python3
from pathlib import Path      
import numpy as np            
import matplotlib.image as mpimg   

BASE_DIR = Path(__file__).resolve().parents[1]
C_OUT = BASE_DIR / "output" / "figures"

# MATLAB project output directory
MAT_OUT = BASE_DIR.parent / "angio2d_ADI" / "output"

# Image pairs to compare (C output, MATLAB reference)
pairs = [
    (C_OUT / "figure_1_campi_2d_t_f.jpeg", MAT_OUT / "fig1.jpeg"),
    (C_OUT / "figure_2_diagnostica_temporale.jpeg", MAT_OUT / "fig2.jpeg"),
    (C_OUT / "figure_3_sezioni_1d.jpeg", MAT_OUT / "fig3.jpeg"),
    (C_OUT / "figure_4_campo_taf.jpeg", MAT_OUT / "fig4.jpeg"),
]


def to_float(img):
    # Convert image to float64 and normalize if integer type
    if img.dtype.kind in ("u", "i"):
        return img.astype(np.float64) / 255.0
    return img.astype(np.float64)


def center_crop_to_match(a, b):
    # Center-crop two images to the common minimum size
    h = min(a.shape[0], b.shape[0])
    w = min(a.shape[1], b.shape[1])

    def crop(x):
        y0 = (x.shape[0] - h) // 2   # Offset verticale
        x0 = (x.shape[1] - w) // 2   # Offset orizzontale
        return x[y0:y0 + h, x0:x0 + w]

    return crop(a), crop(b)


def main():
    compared = 0   # Count comparisons performed

    print("Image comparison C vs MATLAB")
    print("-" * 40)

    for c_file, m_file in pairs:
        if not c_file.exists() or not m_file.exists():
            print(f"SKIP: missing {c_file.name} or {m_file.name}")
            continue

        c_img = to_float(mpimg.imread(c_file))   # Load C image
        m_img = to_float(mpimg.imread(m_file))   # Load MATLAB image

        c_img, m_img = center_crop_to_match(c_img, m_img)   # Align sizes via center crop

        if c_img.shape[2] == 4:
            c_img = c_img[:, :, :3]   # Drop alpha channel if present
        if m_img.shape[2] == 4:
            m_img = m_img[:, :, :3]   # Drop alpha channel if present

        diff = c_img - m_img   # Pixel-wise difference
        mae = float(np.mean(np.abs(diff)))   # Mean Absolute Error
        rmse = float(np.sqrt(np.mean(diff * diff)))   # Root Mean Square Error

        compared += 1

        print(f"{c_file.name}: MAE={mae:.5f}, RMSE={rmse:.5f}")   # Print metrics

    print("-" * 40)

    if compared == 0:
        print("No image pairs available. Comparison skipped.")
        return 0

    print("Lower is better. Near 0 means highly similar visuals.")   # Interpretation
    return 0


if __name__ == "__main__":
    raise SystemExit(main())   # Entry point script