#!/usr/bin/env python3
"""Thin batch wrapper that delegates to run_pipeline shared logic."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from run_pipeline import ROOT, _load_yaml, run_benchmark_from_profile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run OpenMP benchmark from YAML config")
    parser.add_argument("--config", type=str, default="configs/openmp_benchmark.yaml")
    parser.add_argument("--grid", type=int, help="Optional single-grid override")
    parser.add_argument("--threads", type=int, help="Optional single-thread override")
    parser.add_argument("--runs", type=int, help="Optional runs override")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cfg_path = Path(args.config)
    if not cfg_path.is_absolute():
        cfg_path = ROOT / cfg_path
    if not cfg_path.exists():
        raise FileNotFoundError(f"Config not found: {cfg_path}")

    config = _load_yaml(cfg_path)
    if args.grid is not None:
        config["grid_sizes"] = [args.grid]
    if args.threads is not None:
        config["threads"] = [args.threads]
    if args.runs is not None:
        config["runs"] = args.runs

    outdir = Path(config.get("output_dir", "angio2d_c/output"))
    if not outdir.is_absolute():
        outdir = ROOT / outdir

    return run_benchmark_from_profile(config=config, output_dir=outdir)


if __name__ == "__main__":
    raise SystemExit(main())
