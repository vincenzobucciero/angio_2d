# ANGIO2D OpenMP HPC Results

## 1. Benchmark Setup
- Backend: OpenMP (CPU)
- Final benchmark suite: 64x64, 128x128, 256x256
- Thread counts: 1, 2, 3, 4
- Repetitions: 5 runs per configuration
- 512x512 is intentionally **not included** in the final benchmark suite due to current HPC cost/stability constraints.

## 2. Performance Scaling
### Best Result Per Grid

| Grid | Best Threads | Serial Time (s) | Best OpenMP Time (s) | Speedup | Efficiency |
|---|---:|---:|---:|---:|---:|
| 64x64 | 4 | 0.645 | 0.219 | 2.943x | 73.570% |
| 128x128 | 4 | 16.142 | 4.479 | 3.604x | 90.107% |
| 256x256 | 4 | 319.977 | 84.016 | 3.809x | 95.213% |

### Full Thread Table

| Grid | Threads | Mean (s) | Median (s) | Speedup | Efficiency | OK/Fail |
|---|---:|---:|---:|---:|---:|---:|
| 64x64 | 1 | 0.645 | 0.645 | 1.000x | 100.000% | 5/0 |
| 64x64 | 2 | 0.357 | 0.357 | 1.808x | 90.381% | 5/0 |
| 64x64 | 3 | 0.273 | 0.272 | 2.370x | 78.988% | 5/0 |
| 64x64 | 4 | 0.219 | 0.219 | 2.943x | 73.570% | 5/0 |
| 128x128 | 1 | 16.135 | 16.142 | 1.000x | 100.000% | 5/0 |
| 128x128 | 2 | 8.458 | 8.433 | 1.914x | 95.711% | 5/0 |
| 128x128 | 3 | 5.824 | 5.821 | 2.773x | 92.440% | 5/0 |
| 128x128 | 4 | 4.477 | 4.479 | 3.604x | 90.107% | 5/0 |
| 256x256 | 1 | 319.977 | 319.977 | 1.000x | 100.000% | 1/0 |
| 256x256 | 2 | 163.247 | 162.075 | 1.974x | 98.713% | 5/0 |
| 256x256 | 3 | 110.905 | 110.765 | 2.889x | 96.293% | 5/0 |
| 256x256 | 4 | 85.494 | 84.016 | 3.809x | 95.213% | 5/0 |

## 3. Numerical Validation
| Grid | Threads | RelL2 C | RelL2 P | RelL2 Inh | RelL2 F | Diagnostics | Status |
|---|---:|---:|---:|---:|---:|---:|---|
| 64x64 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 64x64 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 128x128 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 256x256 | 1 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | inf | PASS |
| 256x256 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 2 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 3 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |
| 256x256 | 4 | 0.00e+00 | 0.00e+00 | 0.00e+00 | 0.00e+00 | - | PASS |

Validation summary: **56/56 PASS**.

## 4. Discussion
OpenMP scalability improves with grid resolution because computational workload increasingly dominates thread-management overhead. On small grids, scheduling and synchronization overhead is comparatively larger, which limits absolute gains. As resolution increases, ADI diffusion sweeps become the dominant cost and benefit significantly from loop-level parallelization.

The optimal thread count is bounded by hardware resources and residual serial sections. Beyond a certain point, memory bandwidth pressure and synchronization costs reduce incremental gains. This is consistent with strong-scaling behavior expected in shared-memory PDE solvers.

The ADI structure is naturally parallelizable across spatial loops in each sweep, making it a strong candidate for OpenMP acceleration while preserving numerical equivalence with the serial solver.

## 5. Conclusions
- OpenMP delivers robust acceleration up to 4 threads in the final suite.
- Numerical consistency against serial baseline is maintained.
- Reporting artifacts (tables + plots) are now presentation-ready for HPC discussions.
