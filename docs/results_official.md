# Official Results Contract

Questo documento definisce i risultati ufficiali da usare in report/presentazioni.

## Formati ufficiali

- Tabelle numeriche: `csv`
- Log run e note operative: `txt` / `log.txt`
- Figure finali: immagini in `figures/`

## Output standard (single run e batch standard)

Root: `angio2d_c/output/`

Per ogni run:

`<grid>x<grid>-<threads>threads/run-XXX/`

Contenuto minimo richiesto per run:

- `csv/timing.csv`
- `csv/diagnostics_c.csv`
- `csv/run_metadata.csv`
- `csv/solution_c_C.csv`
- `csv/solution_c_P.csv`
- `csv/solution_c_Inh.csv`
- `csv/solution_c_F.csv`
- `figures/` (4 immagini finali)
- `log.txt`

Contenuto minimo richiesto a livello root batch:

- `timing.csv`
- `speedup_summary.md`
- `validation_summary.md`

## Output campaign H100 (CUDA only)

Root: `results/h100_cuda_campaign/`

Contenuto minimo richiesto:

- `cuda_speedup_summary.csv`
- `cuda_speedup_summary.md`
- `cuda_env_report.json`
- `slurm_<JOBID>.out`
- `slurm_<JOBID>.err`

## Artefatti ufficiali già presenti

- report campaign H100: `docs/h100_cuda_campaign_results.md`

## Regola per merge su main

Non si versionano artefatti transienti o raw non necessari.
Si versionano solo risultati riproducibili e leggibili utili a confronto/documentazione.
