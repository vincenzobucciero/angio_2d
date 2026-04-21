#!/usr/bin/env python3
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

BASE_DIR = Path(__file__).resolve().parents[1]
OUTPUT_DIR_C = BASE_DIR / "output-c"
OUTPUT_DIR_C.mkdir(exist_ok=True)

FIG_NAMES = {
    "fig1": "figure_1_campi_2d_t_f.jpeg",
    "fig2": "figure_2_diagnostica_temporale.jpeg",
    "fig3": "figure_3_sezioni_1d.jpeg",
    "fig4": "figure_4_campo_taf.jpeg",
}


def save_figure(fig, name_key: str):
    filename = FIG_NAMES[name_key]
    fig.savefig(OUTPUT_DIR_C / filename, dpi=300)

DIAG_FILE = BASE_DIR / "diagnostics_c.csv"
SOL_FILES = {
    "C": BASE_DIR / "solution_c_C.csv",
    "P": BASE_DIR / "solution_c_P.csv",
    "Inh": BASE_DIR / "solution_c_Inh.csv",
    "F": BASE_DIR / "solution_c_F.csv",
}


def load_diagnostics(path: Path):
    data = np.genfromtxt(path, delimiter=",", skip_header=1)
    return data[:, 0], data[:, 1], data[:, 2], data[:, 3]


def load_solution(path: Path, mx: int, my: int):
    values = np.loadtxt(path)
    return values.reshape((mx, my), order="F")


def main():
    if not DIAG_FILE.exists():
        print(f"Missing diagnostics file: {DIAG_FILE}")
        return 1

    t, mC, mF, En = load_diagnostics(DIAG_FILE)

    mx = 64
    my = 64
    lx = 1.0
    ly = 1.0
    epsilon = 1.0

    x = np.linspace(0.0, lx, mx)
    y = np.linspace(0.0, ly, my)
    X, Y = np.meshgrid(x, y, indexing="ij")

    C = load_solution(SOL_FILES["C"], mx, my)
    P = load_solution(SOL_FILES["P"], mx, my)
    Inh = load_solution(SOL_FILES["Inh"], mx, my)
    F = load_solution(SOL_FILES["F"], mx, my)

    fig1, axes1 = plt.subplots(2, 2, figsize=(10, 8))
    fields = [
        (C, "C  (densita EC)", "viridis"),
        (P, "P  (proteasi)", "hot"),
        (Inh, "Inh  (inibitore)", "cool"),
        (F, "F  (ECM)", "summer"),
    ]
    for ax, (field, label, cmap_name) in zip(axes1.flat, fields):
        im = ax.pcolormesh(X, Y, field, shading="gouraud", cmap=cmap_name)
        ax.set_aspect("equal")
        ax.set_xlabel("x")
        ax.set_ylabel("y")
        ax.set_title(f"{label},  t = {t[-1]:.3f}")
        fig1.colorbar(im, ax=ax)
    fig1.suptitle(f"Angio2D — M_x={mx}, M_y={my}")
    fig1.tight_layout()
    save_figure(fig1, "fig1")
    plt.close(fig1)

    fig2, axes2 = plt.subplots(2, 2, figsize=(10, 8))
    axes2[0, 0].plot(t, mC, "b-", linewidth=1.5)
    axes2[0, 0].set_xlabel("t")
    axes2[0, 0].set_ylabel("∫ C dΩ")
    axes2[0, 0].set_title("Massa cellule endoteliali")
    axes2[0, 0].grid(True, alpha=0.3)

    axes2[0, 1].plot(t, mF, "r-", linewidth=1.5)
    axes2[0, 1].set_xlabel("t")
    axes2[0, 1].set_ylabel("∫ F dΩ")
    axes2[0, 1].set_title("Massa ECM")
    axes2[0, 1].grid(True, alpha=0.3)

    axes2[1, 0].plot(t, En, "k-", linewidth=1.5)
    axes2[1, 0].set_xlabel("t")
    axes2[1, 0].set_ylabel("E(t)")
    axes2[1, 0].set_title("Energia discreta")
    axes2[1, 0].grid(True, alpha=0.3)

    mC_rel = (mC - mC[0]) / max(abs(mC[0]), np.finfo(float).eps)
    mF_rel = (mF - mF[0]) / max(abs(mF[0]), np.finfo(float).eps)
    axes2[1, 1].plot(t, mC_rel, "b--", linewidth=1.2, label="C")
    axes2[1, 1].plot(t, mF_rel, "r--", linewidth=1.2, label="F")
    axes2[1, 1].set_xlabel("t")
    axes2[1, 1].set_ylabel("Δm / m0")
    axes2[1, 1].set_title("Variazione relativa masse")
    axes2[1, 1].legend(loc="best")
    axes2[1, 1].grid(True, alpha=0.3)

    fig2.suptitle("Diagnostica temporale")
    fig2.tight_layout()
    save_figure(fig2, "fig2")
    plt.close(fig2)

    fig3, axes3 = plt.subplots(2, 1, figsize=(9, 7))
    jmid = int(round(my / 2.0)) - 1

    axes3[0].plot(x, C[:, jmid], "b-", linewidth=1.5, label="C")
    axes3[0].plot(x, F[:, jmid], "r--", linewidth=1.5, label="F")
    axes3[0].set_xlabel("x")
    axes3[0].set_ylabel("ampiezza")
    axes3[0].set_title(f"C e F lungo y = {y[jmid]:.2f}")
    axes3[0].legend(loc="best")
    axes3[0].grid(True, alpha=0.3)

    axes3[1].plot(x, P[:, jmid], "m-", linewidth=1.5, label="P")
    axes3[1].plot(x, Inh[:, jmid], "c--", linewidth=1.5, label="Inh")
    axes3[1].set_xlabel("x")
    axes3[1].set_ylabel("ampiezza")
    axes3[1].set_title(f"P e Inh lungo y = {y[jmid]:.2f}")
    axes3[1].legend(loc="best")
    axes3[1].grid(True, alpha=0.3)

    fig3.suptitle("Sezioni 1D — mezzeria")
    fig3.tight_layout()
    save_figure(fig3, "fig3")
    plt.close(fig3)

    T = np.exp(-(1.0 / epsilon) * ((X - lx) ** 2 + (Y - ly / 2.0) ** 2))
    Tx = -2.0 * (1.0 / epsilon) * (X - lx) * T
    Ty = -2.0 * (1.0 / epsilon) * (Y - ly / 2.0) * T

    fig4, ax4 = plt.subplots(figsize=(8, 6))
    im4 = ax4.pcolormesh(X, Y, T, shading="gouraud", cmap="jet")
    skip = max(1, round(mx / 16))
    idx = np.arange(0, mx, skip)
    idy = np.arange(0, my, skip)
    ax4.quiver(X[np.ix_(idx, idy)], Y[np.ix_(idx, idy)], Tx[np.ix_(idx, idy)], Ty[np.ix_(idx, idy)], color="w", scale=18)
    ax4.set_aspect("equal")
    ax4.set_xlabel("x")
    ax4.set_ylabel("y")
    ax4.set_title(f"TAF T(x,y) e ∇T, ε = {epsilon:.2f}")
    fig4.colorbar(im4, ax=ax4)
    fig4.tight_layout()
    save_figure(fig4, "fig4")
    plt.close(fig4)

    print(f"Figures saved in: {OUTPUT_DIR_C}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
