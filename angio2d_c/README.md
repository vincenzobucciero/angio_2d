# ANGIO2D C

Questa cartella contiene la versione C del solver ANGIO2D.

L'obiettivo e` avere un flusso semplice e riproducibile per chiunque cloni il repository:
- compilazione del solver C;
- esecuzione della simulazione;
- generazione delle figure;
- confronto con gli output MATLAB.

## Requisiti

Servono:
- un compilatore C disponibile come `cc`, `clang` o `gcc`
- `make`
- Python 3

Le dipendenze Python richieste sono quelle in `requirements.txt`:
- `numpy`
- `matplotlib`
- `pillow`

## Setup da zero

Dalla root del repository:

```bash
git clone <repo-url>
cd <repo-name>
python3 -m venv .venv
source .venv/bin/activate
pip install -r angio2d_c/requirements.txt
```

Poi entra nella cartella C:

```bash
cd angio2d_c
```

Per il compilatore provare asd eseguire questo comando.
```bash
export CPPFLAGS="-D_GNU_SOURCE -I include"
```

## Flusso completo

Il comando piu` semplice e`:

```bash
python3 scripts/run_pipeline.py
```

Questo fa in sequenza:
1. pulizia di `build/` e `output/`
2. compilazione del solver
3. esecuzione della simulazione
4. generazione figure
5. confronto diagnostica, campi finali e figure con MATLAB

## Esecuzione manuale

Compilare:

```bash
make clean && make
```

Nota:
- non serve impostare `cc99` manualmente
- il progetto passa gia` `-std=c99` tramite il build system
- il compilatore di default e` `cc`
- se serve un compilatore diverso, puoi usare per esempio `make CC=gcc` oppure `make CC=clang`
- se vuoi controllare l'ambiente prima del run puoi usare `make check-env` oppure `make check-python`

Eseguire solo il solver:

```bash
./build/angio2d
```

Target `make` disponibili:

```bash
make
make check-env
make check-python
make run
make figures
make compare
make pipeline
```

Se vuoi usare un interprete Python specifico con i target `make`:

```bash
make compare PYTHON=../.venv/bin/python
make pipeline PYTHON=../.venv/bin/python
```

## OpenMP (fase 2)

La parallelizzazione CPU e` opzionale ed e` attivata via flag build:

```bash
make clean
make USE_OPENMP=1
OMP_NUM_THREADS=4 ./build/angio2d
```

Se il compilatore non supporta `-fopenmp`, puoi passare flag custom:

```bash
make USE_OPENMP=1 OPENMP_CFLAGS=\"...\" OPENMP_LDFLAGS=\"...\"
```

### Test + benchmark fase 2 (quick/full/stress)

Script unico per:
- baseline seriale
- build OpenMP
- verifica numerica vs baseline (`RelL2 <= 1e-6`)
- benchmark thread `1,2,4,8` (5 run, mediana)

```bash
python3 scripts/phase2_test_and_benchmark.py
```

Generare solo le figure:

```bash
python3 scripts/plot_results.py
```

Confrontare la diagnostica C con MATLAB:

```bash
python3 scripts/compare_diagnostics.py
```

Confrontare i campi finali C con MATLAB:

```bash
python3 scripts/compare_fields.py
```

Confrontare le figure C con MATLAB:

```bash
python3 scripts/compare_with_matlab.py
```

Se mancano i file necessari, i confronti vengono saltati:
- se mancano output MATLAB, viene stampato `SKIP`
- se mancano output C, viene stampato `SKIP`
- la pipeline continua comunque

## Output

Tutto l'output del solver C viene salvato sotto `output/`.

Struttura:

```text
output/
  csv/
    diagnostics_c.csv
    run_metadata.csv
    solution_c_C.csv
    solution_c_P.csv
    solution_c_Inh.csv
    solution_c_F.csv
  figures/
    figure_1_campi_2d_t_f.jpeg
    figure_2_diagnostica_temporale.jpeg
    figure_3_sezioni_1d.jpeg
    figure_4_campo_taf.jpeg
```

## Dove cambiare i parametri

I parametri di default del caso di test sono in:

- `src/params.c`

Lì puoi modificare:
- dominio: `Lx`, `Ly`
- griglia: `Mx`, `My`
- tempo finale: `Tf`
- coefficienti di diffusione: `dC`, `dP`, `dI`
- coefficienti di taxis: `alpha1`, `alpha2`, `alpha3`, `alpha4`
- coefficienti di reazione: `k1` ... `k6`
- condizioni iniziali: `C0`, `a`, `sigma_IC`
- parametro TAF: `epsilon`

`hx`, `hy`, `tau` e `Nsteps` vengono ricalcolati automaticamente.

Dopo ogni run, i parametri effettivamente usati vengono salvati in `output/csv/run_metadata.csv`.

## Input MATLAB attesi

Per i confronti con MATLAB, il progetto si aspetta questi file:

```text
../angio2d_ADI/output/csv/diagnostics_matlab.csv
../angio2d_ADI/output/csv/solution_matlab_C.csv
../angio2d_ADI/output/csv/solution_matlab_P.csv
../angio2d_ADI/output/csv/solution_matlab_Inh.csv
../angio2d_ADI/output/csv/solution_matlab_F.csv
../angio2d_ADI/output/fig1.jpeg
../angio2d_ADI/output/fig2.jpeg
../angio2d_ADI/output/fig3.jpeg
../angio2d_ADI/output/fig4.jpeg
```

## Variabili d'ambiente opzionali

Il progetto non richiede variabili d'ambiente obbligatorie.

Opzioni utili:
- `CC`: per scegliere un compilatore diverso da quello di default
- `PYTHON`: per scegliere l'interprete usato dai target `make`
- `ANGIO2D_PYTHON`: per dire alla pipeline quale interprete Python usare

Esempio:

```bash
export ANGIO2D_PYTHON="$(pwd)/../.venv/bin/python"
python3 scripts/run_pipeline.py
```

## Nota sulla riproducibilita`

Il confronto piu` affidabile e` quello numerico:
- `scripts/compare_diagnostics.py`
- `scripts/compare_fields.py`

Il confronto immagini e` utile come controllo visivo, ma non basta da solo a dimostrare coerenza numerica.
