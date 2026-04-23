#!/usr/bin/env python3
from pathlib import Path      # Gestione percorsi
import numpy as np            # Calcolo numerico
import matplotlib

# Backend non interattivo: utile per terminale / CI
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# Directory base del progetto
BASE_DIR = Path(__file__).resolve().parents[1]

# Directory output
OUTPUT_DIR = BASE_DIR / "output"
OUTPUT_DIR.mkdir(exist_ok=True)

# Directory figure
OUTPUT_DIR_FIG = OUTPUT_DIR / "figures"
OUTPUT_DIR_FIG.mkdir(exist_ok=True)

# Nomi standard delle figure generate
FIG_NAMES = {
    "fig1": "figure_1_campi_2d_t_f.jpeg",
    "fig2": "figure_2_diagnostica_temporale.jpeg",
    "fig3": "figure_3_sezioni_1d.jpeg",
    "fig4": "figure_4_campo_taf.jpeg",
}


def save_figure(fig, name_key: str):
    # Salva una figura usando il nome standard associato
    filename = FIG_NAMES[name_key]
    fig.savefig(OUTPUT_DIR_FIG / filename, dpi=300)


# File input principali
DIAG_FILE = OUTPUT_DIR / "csv" / "diagnostics_c.csv"
METADATA_FILE = OUTPUT_DIR / "csv" / "run_metadata.csv"

# File soluzione finale
SOL_FILES = {
    "C": OUTPUT_DIR / "csv" / "solution_c_C.csv",
    "P": OUTPUT_DIR / "csv" / "solution_c_P.csv",
    "Inh": OUTPUT_DIR / "csv" / "solution_c_Inh.csv",
    "F": OUTPUT_DIR / "csv" / "solution_c_F.csv",
}


def load_diagnostics(path: Path):
    # Carica diagnostica: t, mC, mF, En
    data = np.genfromtxt(path, delimiter=",", skip_header=1)
    return data[:, 0], data[:, 1], data[:, 2], data[:, 3]


def load_solution(path: Path, mx: int, my: int):
    # Carica soluzione finale e la rimodella come matrice 2D
    values = np.loadtxt(path)
    return values.reshape((mx, my), order="F")   # ordine MATLAB / Fortran


def load_metadata(path: Path):
    # Carica i parametri numerici della run
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


def main():
    # Verifica file necessari
    if not DIAG_FILE.exists():
        print(f"Missing diagnostics file: {DIAG_FILE}")
        return 1

    if not METADATA_FILE.exists():
        print(f"Missing run metadata file: {METADATA_FILE}")
        return 1

    # Carica diagnostica e metadati
    t, mC, mF, En = load_diagnostics(DIAG_FILE)
    meta = load_metadata(METADATA_FILE)

    mx = meta["mx"]
    my = meta["my"]
    lx = meta["lx"]
    ly = meta["ly"]
    epsilon = meta["epsilon"]

    # Costruisce la griglia
    x = np.linspace(0.0, lx, mx)
    y = np.linspace(0.0, ly, my)
    X, Y = np.meshgrid(x, y, indexing="ij")   # coerente con il solver C / MATLAB

    # Carica campi finali
    C = load_solution(SOL_FILES["C"], mx, my)
    P = load_solution(SOL_FILES["P"], mx, my)
    Inh = load_solution(SOL_FILES["Inh"], mx, my)
    F = load_solution(SOL_FILES["F"], mx, my)

    # ============================================================
    # FIGURA 1: campi 2D finali
    # ============================================================
    fig1, axes1 = plt.subplots(2, 2, figsize=(10, 8))

    fields = [
        (C, "C  (densita EC)", "viridis"),
        (P, "P  (proteasi)", "hot"),
        (Inh, "Inh  (inibitore)", "cool"),
        (F, "F  (ECM)", "summer"),
    ]

    for ax, (field, label, cmap_name) in zip(axes1.flat, fields):
        im = ax.pcolormesh(X, Y, field, shading="gouraud", cmap=cmap_name)   # Mappa 2D
        ax.set_aspect("equal")
        ax.set_xlabel("x")
        ax.set_ylabel("y")
        ax.set_title(f"{label},  t = {t[-1]:.3f}")
        fig1.colorbar(im, ax=ax)

    fig1.suptitle(f"Angio2D — M_x={mx}, M_y={my}, tau={meta['tau']:.2e}")
    fig1.tight_layout()
    save_figure(fig1, "fig1")
    plt.close(fig1)

    # ============================================================
    # FIGURA 2: diagnostica temporale
    # ============================================================
    fig2, axes2 = plt.subplots(2, 2, figsize=(10, 8))

    axes2[0, 0].plot(t, mC, "b-", linewidth=1.5)   # Massa C
    axes2[0, 0].set_xlabel("t")
    axes2[0, 0].set_ylabel("∫ C dΩ")
    axes2[0, 0].set_title("Massa cellule endoteliali")
    axes2[0, 0].grid(True, alpha=0.3)

    axes2[0, 1].plot(t, mF, "r-", linewidth=1.5)   # Massa F
    axes2[0, 1].set_xlabel("t")
    axes2[0, 1].set_ylabel("∫ F dΩ")
    axes2[0, 1].set_title("Massa ECM")
    axes2[0, 1].grid(True, alpha=0.3)

    axes2[1, 0].plot(t, En, "k-", linewidth=1.5)   # Energia
    axes2[1, 0].set_xlabel("t")
    axes2[1, 0].set_ylabel("E(t)")
    axes2[1, 0].set_title("Energia discreta")
    axes2[1, 0].grid(True, alpha=0.3)

    mC_rel = (mC - mC[0]) / max(abs(mC[0]), np.finfo(float).eps)   # Variazione relativa massa C
    mF_rel = (mF - mF[0]) / max(abs(mF[0]), np.finfo(float).eps)   # Variazione relativa massa F

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

    # ============================================================
    # FIGURA 3: sezioni 1D alla mezzeria
    # ============================================================
    fig3, axes3 = plt.subplots(2, 1, figsize=(9, 7))
    jmid = int(round(my / 2.0)) - 1   # Indice della mezzeria discreta

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

    # ============================================================
    # FIGURA 4: campo TAF e gradiente
    # ============================================================
    T = np.exp(-(1.0 / epsilon) * ((X - lx) ** 2 + (Y - ly / 2.0) ** 2))   # Profilo TAF
    Tx = -2.0 * (1.0 / epsilon) * (X - lx) * T   # Gradiente x del TAF
    Ty = -2.0 * (1.0 / epsilon) * (Y - ly / 2.0) * T   # Gradiente y del TAF

    fig4, ax4 = plt.subplots(figsize=(8, 6))
    im4 = ax4.pcolormesh(X, Y, T, shading="gouraud", cmap="jet")

    skip = max(1, round(mx / 16))   # Sottocampionamento frecce
    idx = np.arange(0, mx, skip)
    idy = np.arange(0, my, skip)

    ax4.quiver(
        X[np.ix_(idx, idy)],
        Y[np.ix_(idx, idy)],
        Tx[np.ix_(idx, idy)],
        Ty[np.ix_(idx, idy)],
        color="w",
        scale=18,
    )   # Campo vettoriale del gradiente

    ax4.set_aspect("equal")
    ax4.set_xlabel("x")
    ax4.set_ylabel("y")
    ax4.set_title(f"TAF T(x,y) e ∇T, ε = {epsilon:.2f}")
    fig4.colorbar(im4, ax=ax4)

    fig4.tight_layout()
    save_figure(fig4, "fig4")
    plt.close(fig4)

    print(f"Figures saved in: {OUTPUT_DIR_FIG}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())   # Entry point script