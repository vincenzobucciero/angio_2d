# Test 06-2026

Curated benchmark campaign saved for long-term reference and GitHub publication.

## Scope

- Backends: `serial`, `openmp` (`4` threads), `cuda`
- Grids: `64x64`, `128x128`, `256x256`, `512x512`
- Runs per configuration: `1`
- Source run directories:
  - `results/recheck_compact_serial/`
  - `results/recheck_compact_openmp4/`
  - `results/recheck_compact_cuda/`

## Slurm jobs

- `2219` serial
- `2220` openmp 4-thread
- `2221` cuda

## Execution notes

- CPU/OpenMP benchmark campaign executed on `low-gn`
- CUDA benchmark campaign executed on `low-gn`
- The CUDA job used the compact V100/`low-gn` setup, not the historical H100 campaign

## Summary table

| Grid | Serial (s) | OpenMP 4 threads (s) | CUDA (s) |
|---|---:|---:|---:|
| 64x64 | 1.302683 | 0.935738 | 0.848697 |
| 128x128 | 28.812839 | 10.004226 | 3.779289 |
| 256x256 | 515.795797 | 139.934912 | 28.154520 |
| 512x512 | 10960.187310 | 3219.701683 | 226.773082 |

## Machine-readable files

- `docs/test_06-2026/serial_timing.csv`
- `docs/test_06-2026/openmp4_timing.csv`
- `docs/test_06-2026/cuda_timing.csv`
