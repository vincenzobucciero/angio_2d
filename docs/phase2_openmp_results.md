# Phase 2 OpenMP (User Summary)

La fase OpenMP è stabile e validata su:

- `64x64`
- `128x128`
- `256x256`

`512x512` non è inclusa nella suite finale.

## Cosa può fare l'utente

- Eseguire run singola con backend `openmp` e scelta thread.
- Eseguire batch da YAML.
- Eseguire batch su SLURM con lo stesso comportamento.

## Comandi

```bash
python3 scripts/run_simulation.py --backend openmp --grid 128 --threads 4
python3 scripts/run_batch.py --config configs/run_profile.yaml --backend openmp
sbatch jobs/run_openmp.sbatch --config configs/run_profile.yaml
```

## Output

Output unico in:

`angio2d_c/output/`

Per ogni configurazione:

`<grid>x<grid>-<threads>threads[/run-XXX]/csv`, `figures`, `log.txt`.

## Validazione numerica

La validazione confronta OpenMP con seriale su RelL2 dei campi principali e diagnostiche.
La correttezza numerica resta prioritaria rispetto allo speedup.
