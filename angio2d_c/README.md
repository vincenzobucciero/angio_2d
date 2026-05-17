# ANGIO2D C Module

Questo README non e' la guida utente principale.

Guida ufficiale post-clone:

- `../README.md`

Qui restano solo note tecniche sul modulo C/CUDA (sorgenti, include, build system).

## Build rapido varianti

Da root repository:

```bash
cd angio2d_c
make serial
make openmp
make cuda
```

I binari vengono prodotti in:

- `angio2d_c/bin/angio2d_serial`
- `angio2d_c/bin/angio2d_openmp`
- `angio2d_c/bin/angio2d_cuda`

Per esecuzione, YAML e output run, usare solo i comandi documentati in `../README.md`.
