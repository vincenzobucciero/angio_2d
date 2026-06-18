# ANGIO2D

Repository for the `serial`, `openmp`, and `cuda` implementations of ANGIO2D.

## Prerequisites
- Linux
- `make`
- a C compiler (`gcc` or `clang`)
- Python `3.11+`
- Python packages from `angio2d_c/requirements.txt`
- for CUDA runs: `nvcc` and an NVIDIA GPU

Quick setup:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r angio2d_c/requirements.txt
```

## Main entry points
- Single run: `scripts/run_simulation.py`
- Batch runs from YAML: `scripts/run_batch.py`
- SLURM OpenMP: `jobs/run_openmp.sbatch`
- SLURM CUDA: `jobs/run_cuda.sbatch`
- SLURM H100-oriented CUDA runs: `jobs/run_cuda_h100_campaign.sbatch`

## Tracked benchmark configs
| Config | Purpose | Default backend |
|---|---|---|
| `configs/baseline_serial.yaml` | serial CPU baseline | `serial` |
| `configs/benchmark_openmp.yaml` | OpenMP benchmark | `openmp` |
| `configs/benchmark_gpu.yaml` | CUDA benchmark | `cuda` |
| `configs/h100_two_tests.yaml` | H100 large-grid CUDA run (`1024`, `2048`) | `cuda` |

## Typical commands
```bash
python3 scripts/run_simulation.py --backend serial --grid 128 --threads 1
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1

python3 scripts/run_batch.py --config configs/benchmark_openmp.yaml
python3 scripts/run_batch.py --config configs/benchmark_gpu.yaml

sbatch jobs/run_openmp.sbatch
sbatch jobs/run_cuda.sbatch
sbatch jobs/run_cuda_h100_campaign.sbatch
```

## Official versioned documentation
- Official timings table: `docs/official_timings.csv`
- H100 timing notes: `docs/h100_cuda_campaign_results.md`
- Results policy: `docs/results_official.md`
- Config guide: `configs/README.md`

## Repository hygiene
Generated runtime outputs are local artifacts and are intentionally ignored by git. The repository only versions source code, tracked configs, and curated documentation.
