# Official Results Contract

This document defines the official results to be used in reports and presentations.

## Official formats

- Numerical tables: `csv`
- Run logs and operational notes: `txt` / `log.txt`
- Final figures: images in `figures/`

## Standard output (single run and standard batch)

Root: `angio2d_c/output/`

For each run:

`<grid>x<grid>-<threads>threads/run-XXX/`

Minimum required contents for each run:

- `csv/timing.csv`
- `csv/diagnostics_c.csv`
- `csv/run_metadata.csv`
- `csv/solution_c_C.csv`
- `csv/solution_c_P.csv`
- `csv/solution_c_Inh.csv`
- `csv/solution_c_F.csv`
- `figures/` (4 final images)
- `log.txt`

Minimum required contents at the batch root level:

- `timing.csv`
- `speedup_summary.md`
- `validation_summary.md`

## H100 campaign output (CUDA only)

Root: `results/h100_cuda_campaign/`

Minimum required contents:

- `cuda_speedup_summary.csv`
- `cuda_speedup_summary.md`
- `cuda_env_report.json`
- `slurm_<JOBID>.out`
- `slurm_<JOBID>.err`

## Official artifacts already present

- H100 campaign report: `docs/h100_cuda_campaign_results.md`
- Single official GPU timings table: `docs/official_gpu_times.csv`

## Merge rule for `main`

Do not commit transient or unnecessary raw artifacts.
Only version reproducible, human-readable results useful for comparison/documentation.
