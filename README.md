# ANGIO2D

Repository for the `serial`, `openmp`, and `cuda` implementations of ANGIO2D.

## Usage And Rights

- This repository is proprietary. See `LICENSE.md`.
- No reuse, redistribution, modification, or derivative use is allowed without prior written authorization from:
  - Bucciero Vincenzo
  - Coppola Carmine
  - De Martino Camilla
  - Perrotta Simone

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

## How To Run Your Own Tests

Typical workflow:

1. Choose the backend you want to test:
   - `serial` for single-thread CPU baseline
   - `openmp` for multi-thread CPU tests
   - `cuda` for GPU tests
2. Choose whether you need:
   - one run with `scripts/run_simulation.py`
   - a small benchmark campaign with `scripts/run_batch.py`
   - a cluster submission with `jobs/*.sbatch`
3. Keep your raw outputs under `results/` or `angio2d_c/output/`; only curated summaries under `docs/` are meant to be versioned.

Minimal local examples:

```bash
python3 scripts/run_simulation.py --backend serial --grid 64 --threads 1 --no-generate-plots
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4 --no-generate-plots
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1 --no-generate-plots
```

Batch examples from tracked configs:

```bash
python3 scripts/run_batch.py --config configs/baseline_serial.yaml
python3 scripts/run_batch.py --config configs/benchmark_openmp.yaml
python3 scripts/run_batch.py --config configs/benchmark_gpu.yaml
python3 scripts/run_batch.py --config configs/h100_two_tests.yaml
```

Cluster examples:

```bash
sbatch jobs/run_openmp.sbatch
sbatch jobs/run_cuda.sbatch
sbatch jobs/run_cuda_h100_campaign.sbatch
```

Before launching a benchmark campaign, decide these parameters explicitly:

- grids to test
- OpenMP thread count
- GPU availability
- timeout budget
- whether plots are needed
- where raw results should be stored

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
- Copyright / usage notice: `LICENSE.md`
- Timing summary (Markdown): `docs/timing_summary.md`
- Combined timings table: `docs/official_timings.csv`
- Official serial timings: `docs/official_serial_times.csv`
- Official OpenMP timings: `docs/official_openmp_times.csv`
- H100 timing notes: `docs/h100_cuda_campaign_results.md`
- Results policy: `docs/results_official.md`
- Test 06-2026 campaign: `docs/test_06-2026/README.md`
- Config guide: `configs/README.md`

## Repository hygiene
Generated runtime outputs are local artifacts and are intentionally ignored by git. The repository only versions source code, tracked configs, and curated documentation.