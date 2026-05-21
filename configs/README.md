# ANGIO2D Benchmark Configurations

This directory contains **3 standard benchmark configs** for repeatable testing across all backends.

## 🚀 Quick Start

### 1. Baseline CPU (Serial)
```bash
python3 scripts/run_batch.py --config configs/baseline_serial.yaml
```
Single-threaded reference implementation. All other results compared vs this.

**Output:** `results/baseline_serial/`
- All 4 figures auto-generated in each `*/*/run-*/figures/`

---

### 2. OpenMP Multithread
```bash
python3 scripts/run_batch.py --config configs/benchmark_openmp.yaml
```
Measure CPU parallelization speedup via OpenMP threads.

**Output:** `results/benchmark_openmp/`

**Example speedup output:**
```
512x512-1threads:   250s  (baseline serial, 1 core)
512x512-2threads:   130s  (2x speedup)
512x512-4threads:    65s  (3.8x speedup)
512x512-8threads:    35s  (7.1x speedup - not linear due to memory)
```

---

### 3. GPU CUDA
```bash
# Interactive test (local GPU)
python3 scripts/run_batch.py --config configs/benchmark_gpu.yaml

# Or via SLURM (H100 cluster)
sbatch jobs/run_cuda_h100_campaign.sbatch
```

Measure GPU acceleration. Requires NVIDIA GPU and CUDA toolkit.

**Output:** `results/benchmark_gpu/`
- All 4 figures auto-generated in each `*/*/run-*/figures/`

---

## 📊 Output Structure (Consolidated in `results/`)

```
results/
├── baseline_serial/
│   ├── 64x64-1threads/
│   │   └── run-001/
│   │       ├── csv/
│   │       │   ├── diagnostics_c.csv
│   │       │   ├── solution_c_C.csv, P.csv, Inh.csv, F.csv
│   │       │   ├── timing.csv
│   │       │   └── run_metadata.csv
│   │       ├── figures/              ← Auto-generated if generate_plots: true
│   │       │   ├── figure_1_2d_fields.png
│   │       │   ├── figure_2_temporal.png
│   │       │   ├── figure_3_sections.png
│   │       │   └── figure_4_taf.png
│   │       └── log.txt
│   ├── 128x128-1threads/
│   ...
│   └── serial_speedup_summary.md
│
├── benchmark_openmp/
│   ├── 64x64-1threads/
│   ├── 64x64-2threads/
│   ├── 64x64-4threads/
│   ├── 64x64-8threads/
│   ...
│   └── openmp_speedup_summary.md
│
└── benchmark_gpu/
    ├── 1024x1024-1threads/
    ├── 2048x2048-1threads/
    ...
    └── cuda_speedup_summary.md
```

---

## 🎨 Automatic Plotting

### Enabled by Default (v2.0+)

All 3 benchmark configs now have `generate_plots: true`. This automatically generates **4 standard ANGIO2D figures** per run:

1. **2D fields** — C, P, Inh, F at final time (heatmaps, 300 DPI)
2. **Temporal diagnostics** — mass evolution, energy, relative changes
3. **1D sections** — profiles along midline (C, F, P, Inh)
4. **TAF field** — chemoattractant and gradient vectors

Figures saved in `*/*/run-*/figures/` (~3 MB per run).

### Manual Plotting (Post-Hoc)

Regenerate/update figures for any completed run:

```bash
# Activate Python environment first
source .venv/bin/activate

# Generate 4 figures for specific run
python3 scripts/plot_benchmark_results.py results/baseline_serial/512x512-8threads/run-001/

# Or for GPU test
python3 scripts/plot_benchmark_results.py results/benchmark_gpu/1024x1024-1threads/run-001/
```

Script will create/overwrite PNG files in `figures/` directory.

---

## 🔧 Customizing for Your Machine

### CPU-only machines
Edit `configs/baseline_serial.yaml` and `configs/benchmark_openmp.yaml`:

#### Parameter: `threads` (OpenMP config)
```yaml
# Your machine's CPU core count
# 4-core CPU:  threads: [1, 2, 4]
# 8-core CPU:  threads: [1, 2, 4, 8]
# 16-core CPU: threads: [1, 2, 4, 8, 16]
threads:
  - 1
  - 2
  - 4
  - 8
```

#### Parameter: `grid_sizes`
```yaml
# Your available RAM determines max grid size
# RAM needed ≈ O(N²) where N = grid dimension
# For laptop (8GB RAM):  [64, 128, 256, 512]
# For desktop (16GB RAM): [64, 128, 256, 512, 1024]
# For server (64GB RAM): [64, 128, 256, 512, 1024, 2048]
grid_sizes:
  - 64
  - 128
  - 256
  - 512
```

#### Parameter: `timeout_per_run`
```yaml
# Typical CPU times (single thread):
# 64x64=1s, 128x128=4s, 256x256=30s, 512x512=250s, 1024x1024=6000s
# Safety factor: 3x → timeout: 18000 (5 hours for 1024)
timeout_per_run: 10800  # 3 hours (conservative)
```

#### Parameter: `generate_plots`
```yaml
# Disable if storage constrained (figures: ~3MB per run)
generate_plots: true
```

---

### GPU machines
Edit `configs/benchmark_gpu.yaml`:

#### Parameter: `grid_sizes`
```yaml
# GPUs handle larger grids efficiently
# V100 (sm_70): [512, 1024]
# A100 (sm_80): [1024, 2048]
# H100 (sm_90): [1024, 2048, 4096]
grid_sizes:
  - 1024
  - 2048
```

#### Parameter: `timeout_per_run`
```yaml
# GPU times highly variable; be generous
# H100 examples: 1024x1024=1800s, 2048x2048=15000s
timeout_per_run: 86400  # 24 hours (safe)
```

#### SLURM cluster-specific edits
File: `jobs/run_cuda_h100_campaign.sbatch`

```bash
#SBATCH --partition=h100gpu          # GPU partition name
#SBATCH --gres=gpu:1                 # Number of GPUs
#SBATCH --cpus-per-task=4            # CPU cores
#SBATCH --mem=16G                    # Memory
#SBATCH --time=3-00:00:00            # Time limit
```

---

## 📋 Key Output Files

| File | Purpose |
|------|---------|
| `timing.csv` | Elapsed time for run |
| `diagnostics_c.csv` | Time series: C mass, F mass, energy |
| `solution_c_C.csv` | Final solution: endothelial cells |
| `solution_c_P.csv` | Final solution: protease |
| `solution_c_Inh.csv` | Final solution: inhibitor |
| `solution_c_F.csv` | Final solution: ECM |
| `run_metadata.csv` | Simulation parameters (grid, timestep, etc.) |
| `*speedup_summary.md` | Performance report with speedup table |
| `figure_*.png` | 4 publication-quality plots (300 DPI) |

---

## 📈 Comparing Results

After all 3 configs complete:

```python
import csv

def read_timing(path):
    with open(path) as f:
        for row in csv.DictReader(f):
            return float(row['elapsed_s'])

GPU_time = read_timing("results/benchmark_gpu/1024x1024-1threads/run-001/csv/timing.csv")
CPU_time = read_timing("results/baseline_serial/1024x1024-1threads/run-001/csv/timing.csv")

print(f"GPU speedup: {CPU_time / GPU_time:.1f}x")
```

Or check auto-generated reports:
- `results/baseline_serial/serial_speedup_summary.md`
- `results/benchmark_openmp/openmp_speedup_summary.md`
- `results/benchmark_gpu/cuda_speedup_summary.md`

---

## 🐍 Python Environment

Virtual environment created automatically on first run. Manually set up:

```bash
python3.11 -m venv .venv
source .venv/bin/activate
pip install numpy matplotlib pillow
```

Required for plotting: `numpy`, `matplotlib`, `pillow`

---

## 🗂️ Storage & Cleanup

- **Single output directory:** All results in `results/` (no redundancy)
- **Per-run size:** ~70 MB CSV + ~3 MB figures = 73 MB
- **Total disk for all 3 configs (5 grids, 1-3 runs each):** ~1 GB

To save disk space after analysis:
```bash
rm -rf results/old_benchmark_name/
```

---

## Troubleshooting

### "Grid too large" → out-of-memory
→ Reduce `grid_sizes` in config

### "timeout" → run too slow
→ Increase `timeout_per_run`

### GPU not found → "no cuda"
→ `make cuda-clean && make cuda` + `module load cuda/12.8`

### Plots not generating
→ Check venv: `source .venv/bin/activate && python3 --version`
→ Check permissions: `ls -la results/`

---

## 📌 Default Machine Profile

**This repository is configured for:**
- CPU: 8-core Intel Xeon
- RAM: 64 GB
- GPU: NVIDIA H100 (sm_90)
- Cluster: SLURM h100gpu partition

To adapt, edit the machine-specific parameters in each config file.
