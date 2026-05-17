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
| 64x64 |  |  |  |  |
| 128x128 |  |  |  |  |
| 256x256 |  |  |  |  |
| 512x512 |  |  |  |  |
| 1024x1024 |  |  |  |  |

## Note

- I valori ufficiali devono essere copiati da `cuda_speedup_summary.csv` a fine campagna.
- In caso di preemption/interruzioni, rilanciare il job con la stessa config per mantenere comparabilità.
- Se una griglia fallisce in strict mode, il job si ferma intenzionalmente (no fallback CPU silenzioso).

## Stato Diagnostico 1024 (2026-05-17)

- Job diagnostico: `951`
- Esito: `FAILED` intenzionale via guard-rail (`ExitCode=99`)
- Evidenza: GPU idle per 60s (`util=0%`, `power~89W`) durante run `1024x1024`
- Azione: benchmark one-pass completo bloccato finché non viene risolta la causa sul path CUDA `1024`.
- Riferimento log: `results/h100_cuda_onepass_1024first/diagnostics/slurm_diag_951.out`
