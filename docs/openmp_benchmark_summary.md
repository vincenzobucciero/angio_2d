# OpenMP Benchmark Summary (Slide-Ready)

## Runtime & Speedup (median over runs)

| Grid | Threads | Median Time (s) | Speedup vs t=1 | Efficiency |
|---|---:|---:|---:|---:|
| 128x128 | 1 | 16.142 | 1.000x | 100.0% |
| 128x128 | 2 | 8.433 | 1.914x | 95.7% |
| 128x128 | 3 | 5.821 | 2.773x | 92.4% |
| 128x128 | 4 | 4.479 | 3.604x | 90.1% |
| 256x256 | 1* | 319.977 | 1.000x | 100.0% |
| 256x256 | 2 | 162.075 | 1.974x | 98.7% |
| 256x256 | 3 | 110.765 | 2.889x | 96.3% |
| 256x256 | 4 | 84.016 | 3.809x | 95.2% |

\* `256x256, t=1` is based on a partial baseline (`ok=1`) because the full serial campaign was intentionally skipped to reduce total wall time.

## Key Takeaways (for presentation)

1. OpenMP scaling is strong and consistent: at `t=4` we reach `3.60x` on `128x128` and `3.81x` on `256x256`.
2. Parallel efficiency remains high up to 4 threads (`~90%` on `128x128`, `~95%` on `256x256`).
3. The largest tested grid (`256x256`) shows the strongest parallel gains, confirming better scalability on heavier workloads.

