# Official Results Contract

This document defines which result files are officially versioned in the repository.

## Official versioned artifacts

- `docs/official_timings.csv`
- `docs/h100_cuda_campaign_results.md`

These files are the curated, repository-tracked timing references for reports and presentations.

## Runtime artifacts

Batch outputs under `results/` and `angio2d_c/output/` are generated locally at run time.

- They are useful for reproducing or refreshing measurements.
- They are not official repository artifacts.
- They are intentionally ignored by git, except for curated data copied into `docs/`.

## Merge rule for `main`

Do not commit raw benchmark runs, scheduler logs, profiling dumps, or transient plotting output.
Only commit reproducible source files and curated documentation that summarize validated results.
