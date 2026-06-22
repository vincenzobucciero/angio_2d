# Timing Summary

Curated benchmark summary for the currently tracked ANGIO2D runs.

## Latest consolidated timings

| Grid | Serial (s) | OpenMP 4 threads (s) | CUDA (s) | CUDA H100 (s) |
|---|---:|---:|---:|---:|
| 64x64 | 2.005495 | 0.938539 | 0.914367 | 1.119667 |
| 128x128 | 28.644441 | 9.282914 | - | 3.819542 |
| 256x256 | 556.786684 | 146.195385 | 28.801267 | 28.432417 |
| 512x512 | 10568.630324 | 3391.002739 | 227.890420 | 228.352442 |
| 1024x1024 | - | - | - | 1807.569306 |
| 2048x2048 | - | - | - | 44038.712071 |

## Notes

- OpenMP timings currently tracked in the repository are for `4` threads.
- The `256x256` and `512x512` serial, OpenMP, and CUDA values come from the latest `low-gn` single-run benchmarks.
- H100 timings are tracked separately and summarized from the curated H100 campaign notes.
- The CSV sources remain the canonical machine-readable references:
  - `docs/official_timings.csv`
  - `docs/official_serial_times.csv`
  - `docs/official_openmp_times.csv`
