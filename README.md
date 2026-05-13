# angio_2d

Implementazione MATLAB di un modello bidimensionale di angiogenesi tumorale basato su splitting operatoriale e schema ADI.

## Problema modellato

Il progetto descrive l'evoluzione nel piano di quattro campi accoppiati:

- `C(x,y,t)`: densita di cellule endoteliali
- `P(x,y,t)`: concentrazione di proteasi
- `Inh(x,y,t)`: concentrazione di inibitore angiogenico
- `F(x,y,t)`: densita di matrice extracellulare (ECM)

Il sistema segue l'idea del paper allegato nel PDF: la crescita dei vasi tumorali viene modellata come interazione tra diffusione, chemotassi, haptotassi, proliferazione cellulare e degradazione della matrice extracellulare. La sorgente angiogenica tumorale, indicata come TAF, viene prescritta come un campo stazionario con massimo vicino al bordo destro del dominio, così da guidare il moto delle cellule verso la zona tumorale.

Dal punto di vista numerico il problema viene risolto su un dominio rettangolare con condizioni di Neumann omogenee. La dinamica in tempo è separata in due parti: un passo di reazione/trasporto trattato esplicitamente e un passo diffusivo trattato con ADI di Peaceman-Rachford, in modo da trasformare il problema 2D in una sequenza di sistemi tridiagonali 1D.

## File MATLAB

### `angio2d_ADI/default_params.m`

Definisce tutti i parametri del modello e della discretizzazione. In particolare:

- imposta dominio, griglia e tempo finale
- assegna i coefficienti di diffusione e le costanti cinetiche
- definisce i parametri della chemotassi, haptotassi e del TAF
- imposta le condizioni iniziali
- calcola automaticamente il passo temporale `tau` a partire da una stima CFL e determina il numero di passi `Nsteps`

Questo file non esegue la simulazione: prepara solo la struttura `p` che contiene i parametri necessari a tutto il resto.

### `angio2d_ADI/angio2d_core.m`

Esegue il calcolo numerico vero e proprio. Il file:

- costruisce la griglia 2D uniforme
- costruisce gli operatori discreti 1D di derivata e Laplaciano
- estende questi operatori al caso 2D tramite prodotti di Kronecker
- inizializza i campi `C`, `P`, `Inh` e `F`
- evolve il sistema nel tempo con splitting di Strang
- usa un passo esplicito per il termine di reazione e advezione
- usa ADI per il sottopasso diffusivo di `C`, `P` e `Inh`
- aggiorna le diagnostiche temporali: massa di `C`, massa di `F` ed energia discreta
- restituisce i campi finali e una struttura `diagnostics` con griglia, parametri e serie temporali

In pratica questo è il cuore del solver: dato un insieme di parametri, produce la soluzione al tempo finale.

### `angio2d_ADI/plot_angio2d.m`

Si occupa della visualizzazione dei risultati. A partire dai campi calcolati da `angio2d_core` e dalla struttura `diagnostics`, genera quattro figure:

- mappe 2D finali di `C`, `P`, `Inh` e `F`
- diagnostica temporale di masse ed energia
- sezioni 1D lungo la mezzeria del dominio
- campo TAF con gradiente sovrapposto tramite `quiver`

Il file supporta anche il salvataggio automatico delle figure in una cartella dedicata, in formati come PNG, PDF o EPS.

## Uso tipico

Esempio minimo di esecuzione:

```matlab
p = default_params();
[C, P, Inh, F, diagnostics] = angio2d_core(p);
plot_angio2d(C, P, Inh, F, diagnostics);
```

## Esecuzione da terminale VS Code

Per lavorare direttamente dal terminale integrato di VS Code, senza aprire l'applicazione grafica di MATLAB, usa una delle due modalità seguenti.

### Modalita interattiva

Avvia MATLAB in modalita testuale:

```bash
matlab -nodesktop -nosplash
```

Poi esegui questi comandi dentro MATLAB:

```matlab
cd('/home/vincenzo/Documents/angio_2d/angio2d_ADI')
p = default_params();
[C, P, Inh, F, diagnostics] = angio2d_core(p);
plot_angio2d(C, P, Inh, F, diagnostics);
```

### Modalita batch

Se vuoi eseguire tutto in un solo comando e terminare automaticamente alla fine del calcolo:

```bash
matlab -batch "cd('/home/vincenzo/Documents/angio_2d/angio2d_ADI'); p = default_params(); [C,P,Inh,F,diagnostics] = angio2d_core(p); plot_angio2d(C,P,Inh,F,diagnostics);"
```

Questa seconda opzione e comoda per test ripetibili, automazione e collaborazione tra piu persone.

## Esecuzione con GUI MATLAB

Se vuoi lavorare con l'interfaccia grafica di MATLAB, apri un terminale e lancia semplicemente:

```bash
matlab
```

Questo comando avvia direttamente l'applicazione MATLAB con la GUI. Una volta aperto l'ambiente, imposta la cartella del progetto su `/home/vincenzo/Documents/angio_2d/angio2d_ADI` e poi esegui i comandi di simulazione descritti sopra.

## Struttura del flusso

1. `default_params.m` prepara i parametri.
2. `angio2d_core.m` risolve il modello e restituisce la soluzione finale.
3. `plot_angio2d.m` visualizza e, se richiesto, salva i risultati.

## Riferimento concettuale

La formulazione del problema e la scelta dello schema numerico sono coerenti con il PDF allegato, che introduce un'estensione bidimensionale del modello classico di angiogenesi tumorale e motiva l'uso di operator splitting e ADI per ridurre il costo computazionale della parte diffusiva.

---

## OpenMP Benchmark (HPC Phase 2)

The OpenMP benchmark workflow is fully reproducible through YAML + Python scripts and supports both local execution and SLURM submission.

### Run Workflow

Local:

```bash
python3 scripts/run_openmp_benchmark_from_config.py --config configs/openmp_benchmark.yaml
```

SLURM:

```bash
sbatch jobs/run_openmp_benchmark.sbatch configs/openmp_benchmark.yaml
```

### Final Benchmark Suite

- Grids: `64x64`, `128x128`, `256x256`
- Threads: `1, 2, 3, 4`
- Repetitions: `5 runs/configuration`
- Backend: OpenMP CPU
- `512x512` is **not included** in the final suite due to current HPC cost/stability constraints.

### Professional Reporting Artifacts

Generate presentation-ready HPC reporting:

```bash
python3 scripts/generate_openmp_reporting.py
```

This creates:

`results/openmp_scaling/`

- `csv/`: raw runs, performance summary, best-per-grid table, numerical validation table
- `plots/`: `runtime_vs_threads.png`, `speedup_vs_threads.png`, `efficiency_vs_threads.png`, `runtime_vs_grid.png`
- `logs/`: report generation log
- `figures/`: solver final figures grouped by best thread per grid
- `summaries/`: structured technical summary for report/presentation

For a full technical discussion and interpretation, see:

- `docs/phase2_openmp_results.md`
