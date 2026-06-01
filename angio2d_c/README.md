# ANGIO2D C Module

This README is not the main user guide.

Official post-clone guide:

- `../README.md`

Only technical notes about the C/CUDA module remain here (sources, include, build system).

## Quick build variants

From the repository root:

```bash
cd angio2d_c
make serial
make openmp
make cuda
```

The binaries are produced in:

- angio2d_c/bin/angio2d_serial
- angio2d_c/bin/angio2d_openmp
- angio2d_c/bin/angio2d_cuda

For running, YAMLs and run outputs, use only the commands documented in `../README.md`.
