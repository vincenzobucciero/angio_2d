# Phase 3 CUDA (Kickoff)

CUDA è introdotto come backend aggiuntivo, senza rompere serial/OpenMP.

## Stato attuale

- branch dedicato: `phase3-cuda`
- target iniziale: accelerazione ADI
- suite iniziale: `64/128/256`
- `512x512` esclusa dalla suite iniziale

## Uso utente

Run singola:

```bash
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1 --validate
```

Batch locale:

```bash
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend cuda
```

Batch SLURM:

```bash
sbatch jobs/run_cuda.sbatch --config configs/run_profile.yaml
```

## Verifica ambiente CUDA

```bash
python3 scripts/check_cuda_env.py --output angio2d_c/output/_meta/cuda_env_report.json
```

## Output

Anche con CUDA, output unico in:

`angio2d_c/output/`

con `csv/`, `figures/`, `log.txt` per run.
