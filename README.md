# ANGIO2D

Guida ufficiale unica post-clone per esecuzioni `serial`, `openmp`, `cuda`.

## Prerequisiti
- Linux + `make`
- compilatore C (`gcc` o `clang`)
- Python `3.11+`
- dipendenze Python: `numpy`, `matplotlib`, `pillow`
- per CUDA: `nvcc` + GPU NVIDIA compatibile

Setup rapido:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r angio2d_c/requirements.txt
```

## Entry point ufficiali
- Run singolo: `scripts/run_simulation.py`
- Batch da YAML: `scripts/run_batch.py`
- SLURM OpenMP: `jobs/run_openmp.sbatch`
- SLURM CUDA: `jobs/run_cuda.sbatch`
- SLURM CUDA H100 campaign: `jobs/run_cuda_h100_campaign.sbatch`

Interfacce legacy/deprecate (wrapper benchmark storici e job `*_benchmark.sbatch`) non sono supportate.

## Griglie supportate
`64, 128, 256, 512, 1024`

## YAML canonici
| YAML | Scopo | Comando | Backend | Output |
|---|---|---|---|---|
| `configs/run_profile.yaml` | Profilo standard locale | `python3 scripts/run_batch.py --config configs/run_profile.yaml --backend <serial\|openmp\|cuda>` | serial/openmp/cuda | `angio2d_c/output/` |
| `configs/single_grid_debug.yaml` | Debug rapido singola griglia | `python3 scripts/run_batch.py --config configs/single_grid_debug.yaml --backend <openmp\|cuda\|serial>` | openmp (default) | `angio2d_c/output/` |
| `configs/h100_cuda_campaign.yaml` | Campagna H100 (5 run per griglia) | `sbatch jobs/run_cuda_h100_campaign.sbatch --config configs/h100_cuda_campaign.yaml` | cuda | `results/h100_cuda_campaign/` |

## Quickstart
### Run singolo
```bash
python3 scripts/run_simulation.py --backend serial --grid 128 --threads 1
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1
```

Nota: `run_simulation.py` genera figure di default. Per disabilitarle: `--no-generate-plots`.

### Batch locale
```bash
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend openmp
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend cuda
```

### Batch SLURM
```bash
sbatch jobs/run_openmp.sbatch --config configs/run_profile.yaml
sbatch jobs/run_cuda.sbatch --config configs/run_profile.yaml
```

### H100 CUDA campaign
```bash
sbatch jobs/run_cuda_h100_campaign.sbatch --config configs/h100_cuda_campaign.yaml
```

## Dove trovare risultati
### Output standard
Root: `angio2d_c/output/`

Per run:
`<grid>x<grid>-<threads>threads/run-XXX/`

Contenuto:
- `csv/` (diagnostica, campi finali, metadata, timing)
- `figures/` (4 immagini finali, se plotting attivo)
- `log.txt`

Per batch:
- `timing.csv` (aggregato run-level)
- `speedup_summary.md` (sintesi leggibile)
- `validation_summary.md` (se validazione attiva)

### Output H100 campaign
Root: `results/h100_cuda_campaign/`

Contenuto:
- `cuda_speedup_summary.csv`
- `cuda_speedup_summary.md`
- `cuda_env_report.json`
- `slurm_<JOBID>.out`, `slurm_<JOBID>.err`

## Regole operative CUDA (anti-ambiguità)
- Profiling CUDA dettagliato: OFF di default (`ANGIO2D_CUDA_PROFILE=0`)
- Per abilitarlo: `--cuda-profile-detailed` (CLI) o `ANGIO2D_CUDA_PROFILE=1`
- Strict mode CUDA: ON di default nei benchmark (`ANGIO2D_CUDA_STRICT=1`)
- Se CUDA fallisce in strict mode: run abortisce (no fallback silenzioso CPU)

## Documentazione risultati
- contratto artefatti ufficiali: `docs/results_official.md`
- stato/report campagna H100: `docs/h100_cuda_campaign_results.md`

## Repository hygiene
Non versionare transienti:
- `slurm-*.out`, `slurm-*.err`
- log temporanei profiling
- output intermedi raw non richiesti

Check rapido:
```bash
git ls-files | rg "(run_pipeline|benchmark_from_config|run_.*benchmark\\.sbatch|slurm-|profiling_|results/cuda_profiling/)"
```

Deve restituire vuoto.
