# ANGIO2D

Official post-clone quick guide for running `serial`, `openmp`, and `cuda` backends.

## Prerequisites
- Linux + `make`
- C compiler (`gcc` or `clang`)
- Python `3.11+`
- Python dependencies: `numpy`, `matplotlib`, `pillow`
- For CUDA: `nvcc` and a compatible NVIDIA GPU

Quick setup:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r angio2d_c/requirements.txt
```

## Official entry points
- Single run: `scripts/run_simulation.py`
- YAML-driven batch: `scripts/run_batch.py`
- SLURM OpenMP: `jobs/run_openmp.sbatch`
- SLURM CUDA: `jobs/run_cuda.sbatch`
- SLURM CUDA H100 campaign: `jobs/run_cuda_h100_campaign.sbatch`

Legacy/deprecated wrappers (historical benchmarks and `*_benchmark.sbatch`) are not supported.

## Supported grids
`64, 128, 256, 512, 1024`

## Canonical YAMLs
| YAML | Purpose | Command | Backend | Output |
|---|---|---|---|---|
| `configs/run_profile.yaml` | Standard local profile | `python3 scripts/run_batch.py --config configs/run_profile.yaml --backend <serial\|openmp\|cuda>` | serial/openmp/cuda | `angio2d_c/output/` |
| `configs/single_grid_debug.yaml` | Quick single-grid debug | `python3 scripts/run_batch.py --config configs/single_grid_debug.yaml --backend <openmp\|cuda\|serial>` | openmp (default) | `angio2d_c/output/` |
| `configs/h100_cuda_campaign.yaml` | H100 campaign (5 runs per grid) | `sbatch jobs/run_cuda_h100_campaign.sbatch --config configs/h100_cuda_campaign.yaml` | cuda | `results/h100_cuda_campaign/` |

## Quickstart
### Single run
```bash
python3 scripts/run_simulation.py --backend serial --grid 128 --threads 1
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1
```

Note: `run_simulation.py` generates plots by default. Disable them with `--no-generate-plots`.

### Local batch
```bash
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend openmp
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend cuda
```

### SLURM batch
```bash
sbatch jobs/run_openmp.sbatch --config configs/run_profile.yaml
sbatch jobs/run_cuda.sbatch --config configs/run_profile.yaml
```

### H100 CUDA campaign
```bash
sbatch jobs/run_cuda_h100_campaign.sbatch --config configs/h100_cuda_campaign.yaml
```

## Where to find outputs
### Standard output
Root: `angio2d_c/output/`

Per run:
`<grid>x<grid>-<threads>threads/run-XXX/`

Contents:
- `csv/` (diagnostics, final fields, metadata, timing)
- `figures/` (4 final images, if plotting is enabled)
- `log.txt`

Per batch:
- `timing.csv` (run-level aggregate)
- `speedup_summary.md` (human-readable summary)
- `validation_summary.md` (if validation enabled)

### H100 campaign outputs
Root: `results/h100_cuda_campaign/`

Contents:
- `cuda_speedup_summary.csv`
- `cuda_speedup_summary.md`
- `cuda_env_report.json`
- `slurm_<JOBID>.out`, `slurm_<JOBID>.err`

## CUDA operational rules
- Detailed CUDA profiling: OFF by default (`ANGIO2D_CUDA_PROFILE=0`)
- To enable: `--cuda-profile-detailed` (CLI) or `ANGIO2D_CUDA_PROFILE=1`
- CUDA strict mode: ON by default in benchmarks (`ANGIO2D_CUDA_STRICT=1`)
- If CUDA fails in strict mode: run aborts (no silent CPU fallback)

## Results documentation
- official artifact contract: `docs/results_official.md`
- H100 campaign report: `docs/h100_cuda_campaign_results.md`

## Repository hygiene
Do not commit transient files:
- `slurm-*.out`, `slurm-*.err`
- temporary profiling logs
- unnecessary raw intermediate outputs

Quick check:
```bash
git ls-files | rg "(run_pipeline|benchmark_from_config|run_.*benchmark\\.sbatch|slurm-|profiling_|results/cuda_profiling/)"
```

Should return empty.
