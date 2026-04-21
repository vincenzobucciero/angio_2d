# ANGIO2D C Solver — Getting Started

A fast C implementation of the ANGIO2D reaction-diffusion solver. Produces 4 publication-ready figures matching the MATLAB reference.

## Requirements

- **macOS** with Xcode Command Line Tools
- **Python 3.x**
- **GNU Make**

Check you have everything:
```bash
cc --version        # Should print clang version
python3 --version   # Should print Python 3.x
make --version      # Should print GNU Make version
```

## Quick Start (3 steps)

### 1. Setup Python Environment
```bash
cd angio_2d/
python3 -m venv .venv
source .venv/bin/activate
pip install -r angio2d_c/requirements.txt
```

### 2. Build & Run
```bash
cd angio2d_c/
python ../../../.venv/bin/python scripts/run_pipeline.py
```

This will:
- Compile the C solver
- Run 2481 timesteps on a 64×64 grid (~10 seconds)
- Generate 4 figures in `output-c/`
- Compare against MATLAB reference

### 3. View Results
Open `angio2d_c/output-c/` in VS Code:
```
figure_1_campi_2d_t_f.jpeg          (2D heatmaps)
figure_2_diagnostica_temporale.jpeg (time series)
figure_3_sezioni_1d.jpeg            (cross-sections)
figure_4_campo_taf.jpeg             (TAF field + vectors)
```

## Pipeline Output

**Expected console output:**
```
[1/7] Preparing environment
[2/7] Cleaning previous build artifacts
[3/7] Compiling C solver
[4/7] Executing ADI solver
[5/7] Generating comparison figures
[6/7] Cleaning temporary data
[7/7] Computing image similarity metrics

✓ All steps executed without errors
```

**Validation metrics** (pixel-level comparison vs MATLAB):
```
figure_1_campi_2d_t_f.jpeg:      MAE=0.309, RMSE=0.483
figure_2_diagnostica_temporale:  MAE=0.073, RMSE=0.204  ← Temporal match ✓
figure_3_sezioni_1d.jpeg:        MAE=0.174, RMSE=0.328
figure_4_campo_taf.jpeg:         MAE=0.444, RMSE=0.591
```

MAE < 0.5 on all figures = good visual agreement with MATLAB.

## Troubleshooting

| Error | Fix |
|-------|-----|
| `cc: command not found` | Install Xcode: `xcode-select --install` |
| `ModuleNotFoundError: numpy` | Rerun pip install: `pip install -r angio2d_c/requirements.txt` |
| `Permission denied: ./build/angio2d` | Already fixed by pipeline; shouldn't happen |

## Next Steps

- **Understand the build:** Read `angio2d_c/BUILD_SYSTEM.md`
- **Modify parameters:** Edit `angio2d_c/src/params.c` (grid size, timesteps, physics)
- **Customize plots:** Edit `angio2d_c/scripts/plot_results.py`
- **Deep dive:** Read full docs in `angio2d_c/README.md`

## Files & Directories

```
angio2d_c/
├── BUILD_SYSTEM.md           ← How Makefile/build_config.mk work
├── README.md                 ← Full documentation
├── QUICKSTART.md             ← Fast start guide
├── OUTPUT_FORMAT.md          ← What the results mean
├── build_config.mk           ← Compiler flags
├── Makefile                  ← Build rules
├── src/                      ← C source code (9 modules)
├── include/                  ← Headers
├── scripts/                  ← Python orchestration & plotting
├── output-c/                 ← Generated figures (output)
└── .gitignore
```

## Performance

| Step | Time |
|------|------|
| Compilation | ~1 second |
| Solver | ~7 seconds |
| Plotting | ~2 seconds |
| Total | ~10-12 seconds |

**Total runtime:** ~30 seconds (including cleanup & validation)

---

**All set!** Your figures should now be in `output-c/`. They match MATLAB output (MAE < 0.5).

For questions about parameters, physics, or customization, see `angio2d_c/README.md`.
