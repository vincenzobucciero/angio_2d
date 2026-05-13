# ANGIO2D

Progetto per simulazioni 2D di angiogenesi con tre backend eseguibili:

- `serial`
- `openmp`
- `cuda`

Obiettivo utente: lanciare simulazioni e ottenere sempre gli stessi artefatti:

- output numerici `csv`
- 4 figure finali
- `log.txt` run

## Struttura (chiara e unica)

- `scripts/`: comandi utente (CLI)
- `configs/`: profili YAML
- `jobs/`: wrapper SLURM
- `angio2d_c/`: solver C/OpenMP/CUDA
- `angio2d_c/output/`: unica root risultati

## Comandi principali

### Run singola da terminale

```bash
python3 scripts/run_simulation.py --backend serial --grid 128
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4
python3 scripts/run_simulation.py --backend cuda --grid 128 --threads 1
```

### Run batch locale da config

```bash
python3 scripts/run_batch.py --config configs/run_profile.yaml
```

### Run batch su cluster (SLURM)

```bash
sbatch jobs/run_openmp.sbatch --config configs/run_profile.yaml
sbatch jobs/run_cuda.sbatch --config configs/run_profile.yaml
```

Nota: per OpenMP/CUDA su HPC devi usare partizione/risorse corrette del tuo cluster.

## Config utente

File: `configs/run_profile.yaml`

Campi principali:

- `backend`
- `grid_sizes`
- `threads`
- `runs`
- `validate`
- `generate_plots`
- `output_root`
- `timeout_per_run`
- `continue_on_failure`

Precedenza: `CLI override > YAML > default`.

## Output

Per ogni configurazione:

`angio2d_c/output/<grid>x<grid>-<threads>threads[/run-XXX]/`

con:

- `csv/`
- `figures/`
- `log.txt`

## Compatibilità legacy

Alcuni script/job con nome `*benchmark*` restano solo come wrapper deprecati temporanei.
Interfaccia consigliata: `run_simulation.py`, `run_batch.py`, `run_openmp.sbatch`, `run_cuda.sbatch`.

## Documentazione

- [docs/phase2_openmp_results.md](/home/ccoppola/projects/angio_2d/docs/phase2_openmp_results.md)
- [docs/phase3_cuda_acceleration.md](/home/ccoppola/projects/angio_2d/docs/phase3_cuda_acceleration.md)
