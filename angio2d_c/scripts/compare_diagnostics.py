#!/usr/bin/env python3
from pathlib import Path
import numpy as np

BASE_DIR = Path(__file__).resolve().parents[1]
C_FILE = BASE_DIR / "output" / "csv" / "diagnostics_c.csv"
M_FILE = BASE_DIR.parent / "angio2d_ADI" / "output" / "csv" / "diagnostics_matlab.csv"


def load_csv(path: Path):
    data = np.genfromtxt(path, delimiter=",", skip_header=1)
    return data[:, 0], data[:, 1], data[:, 2], data[:, 3]


def rel_l2(a, b):
    denom = np.linalg.norm(b) + np.finfo(float).eps
    return np.linalg.norm(a - b) / denom


def rel_inf(a, b):
    denom = np.max(np.abs(b)) + np.finfo(float).eps
    return np.max(np.abs(a - b)) / denom


def main():
    if not C_FILE.exists():
        print(f"SKIP: missing file {C_FILE}")
        return 0
    if not M_FILE.exists():
        print(f"SKIP: missing file {M_FILE}")
        print("Export diagnostics_matlab.csv from MATLAB into angio2d_ADI/output/csv/")
        return 0

    tc, mc_c, mf_c, en_c = load_csv(C_FILE)
    tm, mc_m, mf_m, en_m = load_csv(M_FILE)

    n = min(len(tc), len(tm))
    tc = tc[:n]
    tm = tm[:n]
    mc_c = mc_c[:n]
    mf_c = mf_c[:n]
    en_c = en_c[:n]
    mc_m = mc_m[:n]
    mf_m = mf_m[:n]
    en_m = en_m[:n]

    print("Diagnostics comparison C vs MATLAB")
    print("-" * 44)
    print(f"timesteps used: {n}")
    print(f"time relL2:  {rel_l2(tc, tm):.6e}")
    print(f"mC   relL2:  {rel_l2(mc_c, mc_m):.6e}, relInf: {rel_inf(mc_c, mc_m):.6e}")
    print(f"mF   relL2:  {rel_l2(mf_c, mf_m):.6e}, relInf: {rel_inf(mf_c, mf_m):.6e}")
    print(f"En   relL2:  {rel_l2(en_c, en_m):.6e}, relInf: {rel_inf(en_c, en_m):.6e}")
    print("-" * 44)
    print("near 0 -> close numerical match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
