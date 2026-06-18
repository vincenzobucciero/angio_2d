# ANGIO2D Config Guide

This directory contains the tracked YAML configurations used by the benchmark scripts.

## Available configs

| Config | Backend | Purpose |
|---|---|---|
| `configs/baseline_serial.yaml` | `serial` | single-thread CPU baseline |
| `configs/benchmark_openmp.yaml` | `openmp` | CPU scaling with multiple OpenMP thread counts |
| `configs/benchmark_gpu.yaml` | `cuda` | generic CUDA benchmark |
| `configs/h100_two_tests.yaml` | `cuda` | H100-oriented large-grid run for `1024` and `2048` |

## Typical usage

```bash
python3 scripts/run_batch.py --config configs/baseline_serial.yaml
python3 scripts/run_batch.py --config configs/benchmark_openmp.yaml
python3 scripts/run_batch.py --config configs/benchmark_gpu.yaml
python3 scripts/run_batch.py --config configs/h100_two_tests.yaml
```

SLURM wrappers:

```bash
sbatch jobs/run_openmp.sbatch
sbatch jobs/run_cuda.sbatch
sbatch jobs/run_cuda_h100_campaign.sbatch
```

## Notes on outputs

- Each YAML defines its own `output_root`.
- Runtime outputs are generated locally and are intentionally ignored by git.
- Curated benchmark numbers that must stay versioned belong in `docs/official_timings.csv`.

## Editing guidance

- Update `grid_sizes` based on the target machine and run budget.
- Update `threads` only for `benchmark_openmp.yaml`.
- Increase `timeout_per_run` for larger grids or slower hardware.
- Keep `backend` aligned with the intended runner.
