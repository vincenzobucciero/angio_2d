#!/usr/bin/env python3
"""
Flexible plotting utility for ANGIO2D benchmark results.
Accepts output directory as argument to generate 4 standard figures.
"""

import sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")  # Non-interactive backend
import matplotlib.pyplot as plt


def load_diagnostics(path: Path):
    """Load diagnostics: t, mC, mF, En"""
    data = np.genfromtxt(path, delimiter=",", skip_header=1)
    return data[:, 0], data[:, 1], data[:, 2], data[:, 3]


def load_solution(path: Path, mx: int, my: int):
    """Load and reshape solution to 2D matrix"""
    values = np.loadtxt(path)
    return values.reshape((mx, my), order="F")


def load_metadata(path: Path):
    """Load run metadata"""
    data = np.genfromtxt(path, delimiter=",", names=True)
    return {
        "mx": int(data["Mx"]),
        "my": int(data["My"]),
        "lx": float(data["Lx"]),
        "ly": float(data["Ly"]),
        "hx": float(data["hx"]),
        "hy": float(data["hy"]),
        "tf": float(data["Tf"]),
        "tau": float(data["tau"]),
        "nsteps": int(data["Nsteps"]),
        "epsilon": float(data["epsilon"]),
    }


def generate_plots(output_dir: Path) -> int:
    """Generate 4 standard ANGIO2D result figures"""
    
    output_dir = Path(output_dir).resolve()
    csv_dir = output_dir / "csv"
    fig_dir = output_dir / "figures"
    fig_dir.mkdir(parents=True, exist_ok=True)
    
    # Check required files
    diag_file = csv_dir / "diagnostics_c.csv"
    meta_file = csv_dir / "run_metadata.csv"
    
    if not diag_file.exists():
        print(f"ERROR: Missing {diag_file}")
        return 1
    if not meta_file.exists():
        print(f"ERROR: Missing {meta_file}")
        return 1
    
    # Load data
    t, mC, mF, En = load_diagnostics(diag_file)
    meta = load_metadata(meta_file)
    
    mx, my = meta["mx"], meta["my"]
    lx, ly = meta["lx"], meta["ly"]
    epsilon = meta["epsilon"]
    
    # Build grid
    x = np.linspace(0.0, lx, mx)
    y = np.linspace(0.0, ly, my)
    X, Y = np.meshgrid(x, y, indexing="ij")
    
    # Load solution fields
    sol_files = {
        "C": csv_dir / "solution_c_C.csv",
        "P": csv_dir / "solution_c_P.csv",
        "Inh": csv_dir / "solution_c_Inh.csv",
        "F": csv_dir / "solution_c_F.csv",
    }
    
    C = load_solution(sol_files["C"], mx, my)
    P = load_solution(sol_files["P"], mx, my)
    Inh = load_solution(sol_files["Inh"], mx, my)
    F = load_solution(sol_files["F"], mx, my)
    
    # FIGURE 1: 2D fields at final time
    fig1, axes1 = plt.subplots(2, 2, figsize=(10, 8))
    fields = [
        (C, "C  (endothelial cells)", "viridis"),
        (P, "P  (protease)", "hot"),
        (Inh, "Inh  (inhibitor)", "cool"),
        (F, "F  (ECM)", "summer"),
    ]
    
    for ax, (field, label, cmap_name) in zip(axes1.flat, fields):
        im = ax.pcolormesh(X, Y, field, shading="gouraud", cmap=cmap_name)
        ax.set_aspect("equal")
        ax.set_xlabel("x")
        ax.set_ylabel("y")
        ax.set_title(f"{label},  t = {t[-1]:.3f}")
        fig1.colorbar(im, ax=ax)
    
    fig1.suptitle(f"Angio2D — Mx={mx}, My={my}, tau={meta['tau']:.2e}")
    fig1.tight_layout()
    fig1.savefig(fig_dir / "figure_1_2d_fields.png", dpi=300)
    print(f"✓ Saved: figure_1_2d_fields.png")
    plt.close(fig1)
    
    # FIGURE 2: temporal diagnostics
    fig2, axes2 = plt.subplots(2, 2, figsize=(10, 8))
    
    axes2[0, 0].plot(t, mC, "b-", linewidth=1.5)
    axes2[0, 0].set_xlabel("t")
    axes2[0, 0].set_ylabel("∫ C dΩ")
    axes2[0, 0].set_title("Cell mass (C)")
    axes2[0, 0].grid(True, alpha=0.3)
    
    axes2[0, 1].plot(t, mF, "r-", linewidth=1.5)
    axes2[0, 1].set_xlabel("t")
    axes2[0, 1].set_ylabel("∫ F dΩ")
    axes2[0, 1].set_title("ECM mass (F)")
    axes2[0, 1].grid(True, alpha=0.3)
    
    axes2[1, 0].plot(t, En, "k-", linewidth=1.5)
    axes2[1, 0].set_xlabel("t")
    axes2[1, 0].set_ylabel("E(t)")
    axes2[1, 0].set_title("Discrete energy")
    axes2[1, 0].grid(True, alpha=0.3)
    
    mC_rel = (mC - mC[0]) / max(abs(mC[0]), np.finfo(float).eps)
    mF_rel = (mF - mF[0]) / max(abs(mF[0]), np.finfo(float).eps)
    
    axes2[1, 1].plot(t, mC_rel, "b--", linewidth=1.2, label="C")
    axes2[1, 1].plot(t, mF_rel, "r--", linewidth=1.2, label="F")
    axes2[1, 1].set_xlabel("t")
    axes2[1, 1].set_ylabel("Δm / m0")
    axes2[1, 1].set_title("Relative mass change")
    axes2[1, 1].legend(loc="best")
    axes2[1, 1].grid(True, alpha=0.3)
    
    fig2.suptitle("Temporal diagnostics")
    fig2.tight_layout()
    fig2.savefig(fig_dir / "figure_2_temporal.png", dpi=300)
    print(f"✓ Saved: figure_2_temporal.png")
    plt.close(fig2)
    
    # FIGURE 3: 1D sections at midline
    fig3, axes3 = plt.subplots(2, 1, figsize=(9, 7))
    jmid = int(round(my / 2.0)) - 1
    
    axes3[0].plot(x, C[:, jmid], "b-", linewidth=1.5, label="C")
    axes3[0].plot(x, F[:, jmid], "r--", linewidth=1.5, label="F")
    axes3[0].set_xlabel("x")
    axes3[0].set_ylabel("amplitude")
    axes3[0].set_title(f"C and F along y = {y[jmid]:.2f}")
    axes3[0].legend(loc="best")
    axes3[0].grid(True, alpha=0.3)
    
    axes3[1].plot(x, P[:, jmid], "m-", linewidth=1.5, label="P")
    axes3[1].plot(x, Inh[:, jmid], "c--", linewidth=1.5, label="Inh")
    axes3[1].set_xlabel("x")
    axes3[1].set_ylabel("amplitude")
    axes3[1].set_title(f"P and Inh along y = {y[jmid]:.2f}")
    axes3[1].legend(loc="best")
    axes3[1].grid(True, alpha=0.3)
    
    fig3.suptitle("1D sections — midline")
    fig3.tight_layout()
    fig3.savefig(fig_dir / "figure_3_sections.png", dpi=300)
    print(f"✓ Saved: figure_3_sections.png")
    plt.close(fig3)
    
    # FIGURE 4: TAF field and gradient
    T = np.exp(-(1.0 / epsilon) * ((X - lx) ** 2 + (Y - ly / 2.0) ** 2))
    Tx = -2.0 * (1.0 / epsilon) * (X - lx) * T
    Ty = -2.0 * (1.0 / epsilon) * (Y - ly / 2.0) * T
    
    fig4, ax4 = plt.subplots(figsize=(8, 6))
    im4 = ax4.pcolormesh(X, Y, T, shading="gouraud", cmap="jet")
    
    skip = max(1, round(mx / 16))
    idx = np.arange(0, mx, skip)
    idy = np.arange(0, my, skip)
    
    ax4.quiver(
        X[np.ix_(idx, idy)],
        Y[np.ix_(idx, idy)],
        Tx[np.ix_(idx, idy)],
        Ty[np.ix_(idx, idy)],
        color="w",
        scale=18,
    )
    
    ax4.set_aspect("equal")
    ax4.set_xlabel("x")
    ax4.set_ylabel("y")
    ax4.set_title(f"TAF T(x,y) and ∇T, ε = {epsilon:.2f}")
    fig4.colorbar(im4, ax=ax4)
    fig4.tight_layout()
    fig4.savefig(fig_dir / "figure_4_taf.png", dpi=300)
    print(f"✓ Saved: figure_4_taf.png")
    plt.close(fig4)
    
    print(f"\n✓ All 4 figures generated in: {fig_dir}")
    return 0


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 plot_benchmark_results.py <output_dir>")
        print("  output_dir: Path to benchmark output (contains csv/ subdirectory)")
        print("\nExample:")
        print("  python3 plot_benchmark_results.py results/benchmark_gpu/1024x1024-1threads/run-001/")
        return 1
    
    output_dir = sys.argv[1]
    return generate_plots(output_dir)


if __name__ == "__main__":
    sys.exit(main())
