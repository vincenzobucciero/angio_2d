# H100 CUDA Campaign Results

Questa pagina raccoglie i risultati ufficiali della campagna CUDA su partizione `h100gpu`.

## Setup

- Backend: `cuda` (solo CUDA, nessuna validazione serial)
- Griglie: `64, 128, 256, 512, 1024`
- Run per griglia: `5`
- Config: `configs/h100_cuda_campaign.yaml`
- Job script: `jobs/run_cuda_h100_campaign.sbatch`
- Strict mode: `ANGIO2D_CUDA_STRICT=1` (default)
- Profiling dettagliato: OFF (`ANGIO2D_CUDA_PROFILE=0`, salvo override esplicito)

## Artefatti sorgente

- Output root: `results/h100_cuda_campaign/`
- Environment report: `results/h100_cuda_campaign/cuda_env_report.json`
- Log scheduler: `results/h100_cuda_campaign/slurm_<JOBID>.out`
- Summary aggregato: `results/h100_cuda_campaign/cuda_speedup_summary.csv`
- Summary leggibile: `results/h100_cuda_campaign/cuda_speedup_summary.md`

## Tabella finale (da compilare a job concluso)

| Grid | Runs OK | Runs Failed | Mean Time (s) | Median Time (s) |
|---|---:|---:|---:|---:|
| 64x64 | 1 | 0 | 1.119667 | 1.119667 |
| 128x128 | 1 | 0 | 3.819542 | 3.819542 |
| 256x256 | 1 | 0 | 28.432417 | 28.432417 |
| 512x512 | 1 | 0 | 228.352442 | 228.352442 |
| 1024x1024 | 1 | 0 | 6040.868769 | 6040.868769 |

## Note

- I valori ufficiali devono essere copiati da `cuda_speedup_summary.csv` a fine campagna.
- In caso di preemption/interruzioni, rilanciare il job con la stessa config per mantenere comparabilità.
- Se una griglia fallisce in strict mode, il job si ferma intenzionalmente (no fallback CPU silenzioso).

## Confronti ufficiali (sintesi)

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

Nota:
- Su `512` e `1024` il seriale non è stato completato.
- Run CUDA validate con `effective_backend=cuda` e `fallback_cpu_detected=no`.
- CSV ufficiale unico: `docs/official_gpu_times.csv`.

## Stato Diagnostico 1024 (storico)

- In una fase precedente il run `1024` falliva e attivava strict mode.
- La causa era nel kernel CUDA ADI (buffer Thomas dimensionati in modo fisso).
- Stato attuale: fix applicato, run `1024` completato su GPU (`6040.868769 s`).
