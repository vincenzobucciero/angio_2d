#!/usr/bin/env python3
from pathlib import Path
import numpy as np

BASE_DIR = Path(__file__).resolve().parents[1]
MATLAB_DIR = BASE_DIR.parent / "angio2d_ADI" / "output" / "csv"


def rel_l2(a, b):
    denom = np.linalg.norm(b) + np.finfo(float).eps
    return np.linalg.norm(a - b) / denom


def rel_inf(a, b):
    denom = np.max(np.abs(b)) + np.finfo(float).eps
    return np.max(np.abs(a - b)) / denom


def main():
    fields = ["C", "P", "Inh", "F"]
    print("Final field comparison C vs MATLAB")
    print("-" * 44)
    compared = 0

    for field in fields:
        c_file = BASE_DIR / "output" / "csv" / f"solution_c_{field}.csv"
        m_file = MATLAB_DIR / f"solution_matlab_{field}.csv"

        if not c_file.exists():
            print(f"SKIP: missing file {c_file}")
            continue
        if not m_file.exists():
            print(f"SKIP: missing file {m_file}")
            continue

        c = np.loadtxt(c_file, delimiter=",").reshape(-1)
        m = np.loadtxt(m_file, delimiter=",").reshape(-1)

        if c.shape != m.shape:
            print(f"{field}: shape mismatch C={c.shape}, MATLAB={m.shape}")
            return 1

        diff = c - m
        idx = int(np.argmax(np.abs(diff)))
        compared += 1
        print(
            f"{field:>3} relL2={rel_l2(c, m):.6e} "
            f"relInf={rel_inf(c, m):.6e} "
            f"absMax={np.max(np.abs(diff)):.6e} "
            f"argmax={idx}"
        )

    print("-" * 44)
    if compared == 0:
        print("No field pairs available. Comparison skipped.")
        return 0
    print("near 0 -> close numerical match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
