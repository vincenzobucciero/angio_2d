# H100 CUDA Campaign Results

This page collects the official results of the CUDA campaign on the `h100gpu` partition.

## Setup

- Backend: `cuda` (CUDA-only, no serial validation)
- Grids: `64, 128, 256, 512, 1024`
- Runs per grid: `5`
- Config: `configs/h100_cuda_campaign.yaml`
- Job script: `jobs/run_cuda_h100_campaign.sbatch`
- Strict mode: `ANGIO2D_CUDA_STRICT=1` (default)
- Detailed profiling: OFF (`ANGIO2D_CUDA_PROFILE=0`, unless explicitly overridden)

## Source artifacts

- Output root: `results/h100_cuda_campaign/`
- Environment report: `results/h100_cuda_campaign/cuda_env_report.json`
- Scheduler log: `results/h100_cuda_campaign/slurm_<JOBID>.out`
- Aggregated summary: `results/h100_cuda_campaign/cuda_speedup_summary.csv`
- Human-readable summary: `results/h100_cuda_campaign/cuda_speedup_summary.md`

## Tabella finale (da compilare a job concluso)

| Grid | Runs OK | Runs Failed | Mean Time (s) | Median Time (s) |
|---|---:|---:|---:|---:|
| 64x64 | 1 | 0 | 1.119667 | 1.119667 |
| 128x128 | 1 | 0 | 3.819542 | 3.819542 |
| 256x256 | 1 | 0 | 28.432417 | 28.432417 |
| 512x512 | 1 | 0 | 228.352442 | 228.352442 |
| 1024x1024 | 1 | 0 | 6040.868769 | 6040.868769 |

## Note

- Official values must be copied from `cuda_speedup_summary.csv` at campaign end.
- In case of preemption or interruptions, re-run the job with the same config to preserve comparability.
- If a grid fails in strict mode, the job stops intentionally (no silent CPU fallback).

## Official comparisons (summary)

### CPU vs OpenMP (baseline utente)
| Grid | CPU serial t=1 median (s) | OpenMP best median (s) | Best speedup |
|---|---:|---:|---:|
| 64x64 | 0.645349 | 0.219299 | 2.9428x |
| 128x128 | 16.142345 | 4.478649 | 3.6043x |
| 256x256 | 319.976824 | 84.016191 | 3.8085x |
| 512x512 | n.d. | n.d. | n.d. |
| 1024x1024 | n.d. | n.d. | n.d. |

### CPU vs GPU CUDA (ultimo job, strict mode)
| Grid | CPU serial (s) | GPU CUDA (s) | GPU/CPU |
|---|---:|---:|---:|
| 64x64 | 0.645349 | 1.119667 | 1.74x |
| 128x128 | 16.142345 | 3.819542 | 0.24x |
| 256x256 | 319.976824 | 28.432417 | 0.09x |
| 512x512 | n.d. | 228.352442 | n.d. |
| 1024x1024 | n.d. | 6040.868769 | n.d. |

Note:
- The serial run was not completed for `512` and `1024`.
- CUDA validate runs use `effective_backend=cuda` and `fallback_cpu_detected=no`.
- Single official CSV: `docs/official_gpu_times.csv`.

## Stato Diagnostico 1024 (storico)

-- In an earlier phase the `1024` run failed and triggered strict mode.
-- The cause was in the CUDA ADI kernel (Thomas buffers with fixed sizing).
-- Current status: fix applied; `1024` run completed on GPU (`6040.868769 s`).
