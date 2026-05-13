#!/usr/bin/env python3
"""Deprecated compatibility wrapper; prefer scripts/run_batch.py."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from _pipeline_core import ROOT, _load_yaml, resolve_output_root, run_benchmark_from_profile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="DEPRECATED: use scripts/run_batch.py")
    parser.add_argument("--config", type=str, default="configs/cuda_benchmark.yaml")
    parser.add_argument("--grid", type=int, help="Optional single-grid override")
    parser.add_argument("--runs", type=int, help="Optional runs override")
    parser.add_argument("--threads", type=int, help="Optional host-thread override")
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
    if args.runs is not None:
        config["runs"] = args.runs
    if args.threads is not None:
        config["threads"] = [args.threads]

    print(
        "DEPRECATION WARNING: use 'python3 scripts/run_batch.py --config configs/run_profile.yaml --backend cuda'",
        file=sys.stderr,
    )

    config["backend"] = "cuda"
    outdir = resolve_output_root(config)
    return run_benchmark_from_profile(config=config, output_dir=outdir)


if __name__ == "__main__":
    raise SystemExit(main())
