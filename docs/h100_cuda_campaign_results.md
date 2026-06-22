# H100 CUDA Timing Notes

This page collects the official H100 CUDA timings that are summarized in `docs/official_timings.csv`.

## Tracked inputs

- Job script: `jobs/run_cuda_h100_campaign.sbatch`
- Large-grid config currently tracked in the repository: `configs/h100_two_tests.yaml`
- Official timing table: `docs/official_timings.csv`

## Historical runtime sources

The numerical values came from local runtime artifacts that are intentionally not versioned in git.
The two sources used to curate the current official table are:

- the historical H100 campaign summarized in this document
- the later large-grid rerun recorded locally under `results/h100_two_tests/`

## Official H100 timings

| Grid | Official H100 time (s) | Notes |
|---|---:|---|
| 64x64 | 1.119667 | historical campaign value |
| 128x128 | 3.819542 | historical campaign value |
| 256x256 | 28.432417 | historical campaign value |
| 512x512 | 228.352442 | historical campaign value |
| 1024x1024 | 1807.569306 | optimized result |
| 2048x2048 | 44038.712071 | large-grid H100 run from the tracked `h100_two_tests` setup |

## Notes

- The `1024x1024` value `1807.569306 s` is the tracked optimized H100 result.
- `docs/official_timings.csv` is the primary repository-tracked table; this page only explains the H100-specific context.
