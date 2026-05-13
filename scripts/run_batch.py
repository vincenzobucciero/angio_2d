#!/usr/bin/env python3
"""User-facing batch entrypoint for multiple runs from config."""

from __future__ import annotations

import argparse
from pathlib import Path

from _pipeline_core import ROOT, _load_yaml, resolve_output_root, run_benchmark_from_profile


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run ANGIO2D batch simulations from YAML profile")
    parser.add_argument("--config", type=str, default="configs/run_profile.yaml")
    parser.add_argument("--backend", choices=["serial", "openmp", "cuda"], help="Override backend from config")
    parser.add_argument("--grid", type=int, help="Optional single-grid override")
    parser.add_argument("--threads", type=int, help="Optional single-thread override")
    parser.add_argument("--runs", type=int, help="Optional runs override")
    parser.add_argument("--validate", action="store_true", help="Enable validation")
    parser.add_argument("--generate-plots", action="store_true", help="Enable final 4 figures")
    parser.add_argument("--output-root", type=str, help="Output root override")
    parser.add_argument("--timeout-per-run", type=int, help="Timeout override")
    parser.add_argument("--continue-on-failure", action="store_true", help="Continue if one run fails")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    cfg_path = Path(args.config)
    if not cfg_path.is_absolute():
        cfg_path = ROOT / cfg_path
    if not cfg_path.exists():
        raise FileNotFoundError(f"Config not found: {cfg_path}")

    config = _load_yaml(cfg_path)
    if args.backend:
        config["backend"] = args.backend
    if args.grid is not None:
        config["grid_sizes"] = [args.grid]
    if args.threads is not None:
        config["threads"] = [args.threads]
    if args.runs is not None:
        config["runs"] = args.runs
    if args.validate:
        config["validate"] = True
        config["validate_against_serial"] = True
    if args.generate_plots:
        config["generate_plots"] = True
    if args.timeout_per_run is not None:
        config["timeout_per_run"] = args.timeout_per_run
    if args.continue_on_failure:
        config["continue_on_failure"] = True

    outdir = resolve_output_root(config, output_override=args.output_root)
    return run_benchmark_from_profile(config=config, output_dir=outdir)


if __name__ == "__main__":
    raise SystemExit(main())
