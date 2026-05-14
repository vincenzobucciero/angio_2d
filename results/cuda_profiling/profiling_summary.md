# CUDA ADI Profiling Report

Generated: 2026-05-14T16:00:06.335696

## Benchmark Results

| Grid | Backend | Wall Time (s) | Solver Time (s) | Speedup |
|------|---------|---------------|-----------------|----------|
| 64x64 | CUDA   |          2.14 |            2.14 | 0.54x    |
| 64x64 | CPU    |          1.16 |            1.16 | -        |
| 128x128 | CUDA   |         20.77 |           20.77 | 0.83x    |
| 128x128 | CPU    |         17.15 |           17.15 | -        |
| 256x256 | CUDA   |        300.18 |          300.18 | 1.03x    |
| 256x256 | CPU    |        309.75 |          309.75 | -        |

## CUDA Profiling Details


## Analysis

### Observations
- See detailed results in `results/cuda_profiling/`
- Profiling logs: `cuda_profiling_log.txt` in each run directory
- Timing data: `csv/timing.csv` in each run directory
