# Phase 2 OpenMP Results (HPC Reporting)

## 1. Benchmark Setup

This phase evaluates OpenMP scalability of the ANGIO2D C solver under a fixed numerical model and validated workflow.

- Backend: OpenMP (shared-memory CPU)
- Benchmark grids: `64x64`, `128x128`, `256x256`
- Thread counts: `1, 2, 3, 4`
- Repetitions: `5 runs` per `(grid, threads)` configuration
- Execution modes:
  - local via Python CLI
  - HPC via SLURM wrapper (`sbatch`)
- Numerical validation: relative L2 comparison against serial baseline fields and diagnostics.

The `512x512` case is intentionally **not included** in the final benchmark suite, due to current HPC allocation cost/stability constraints.

## 2. Performance Scaling

The reporting pipeline produces:

- best-per-grid summary table
- full per-thread table
- runtime/speedup/efficiency plots

Required benchmark plots:

- `runtime_vs_threads.png`
- `speedup_vs_threads.png`
- `efficiency_vs_threads.png`
- `runtime_vs_grid.png`

All are generated in:

`results/openmp_scaling/plots/`

## 3. Numerical Validation

Validation is reported independently from performance:

- RelL2 Diagnostics
- RelL2 C
- RelL2 P
- RelL2 Inh
- RelL2 F
- pass/fail status per run

Validation table artifact:

`results/openmp_scaling/csv/openmp_validation_summary.csv`

This separation prevents conflating speedup analysis with correctness checks.

## 4. Discussion

OpenMP scalability improves as grid resolution increases because arithmetic workload progressively dominates thread-management overhead. On small grids, synchronization and scheduling overhead are relatively more expensive, reducing strong-scaling gains.

The ADI diffusion stage is the dominant computational bottleneck and naturally benefits from loop-level OpenMP parallelization. As grid size grows, the diffusion sweeps amortize parallel overhead more effectively, yielding stronger speedup and improved thread utilization.

Scaling does not increase indefinitely with thread count: memory bandwidth pressure, cache effects, and remaining serial sections limit asymptotic efficiency. This behavior is consistent with expected shared-memory strong scaling for stencil/PDE workloads.

## 5. Conclusions

- The OpenMP solver achieves robust acceleration up to 4 threads on the final benchmark suite.
- Numerical agreement with the serial baseline is preserved across benchmarked configurations.
- Results are now organized into a professional HPC reporting package suitable for:
  - academic report sections
  - final project presentation
  - paper-style performance discussion

## Reproducible Commands

Run benchmark suite:

```bash
python3 scripts/run_openmp_benchmark_from_config.py --config configs/openmp_benchmark.yaml
```

Generate reporting package:

```bash
python3 scripts/generate_openmp_reporting.py
```

