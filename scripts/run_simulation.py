#!/usr/bin/env python3
"""User-facing single simulation entrypoint."""

from __future__ import annotations

import argparse
from pathlib import Path

from _pipeline_core import _single_run, resolve_output_root


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run one ANGIO2D simulation and produce CSV + figures")
    parser.add_argument("--backend", choices=["serial", "openmp", "cuda"], default="serial")
    parser.add_argument("--grid", type=int, required=True, help="Grid size (64, 128, 256)")
    parser.add_argument("--threads", type=int, default=1, help="Threads for OpenMP/CUDA host-side execution")
    parser.add_argument("--validate", action="store_true", help="Validate against serial baseline")
    parser.add_argument("--generate-plots", action="store_true", help="Generate final 4 figures")
    parser.add_argument("--output-root", type=str, default="angio2d_c/output", help="Output root directory")
    parser.add_argument("--timeout-per-run", type=int, default=600)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    outdir = resolve_output_root({}, output_override=args.output_root)
    return _single_run(
        grid=args.grid,
        threads=args.threads,
        backend=args.backend,
        validate=args.validate,
        generate_plots=args.generate_plots or True,
        output_dir=outdir,
        timeout_s=args.timeout_per_run,
    )


if __name__ == "__main__":
    raise SystemExit(main())
