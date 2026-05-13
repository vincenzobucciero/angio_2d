#!/usr/bin/env python3
"""Unified ANGIO2D execution pipeline (single run + batch benchmark)."""

from __future__ import annotations

import argparse
import csv
import math
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from statistics import mean, median
from typing import Dict, List, Optional

try:
    import yaml  # type: ignore
except ImportError:  # pragma: no cover
    yaml = None


ROOT = Path(__file__).resolve().parents[1]
ANGIO2D_C = ROOT / "angio2d_c"
BENCHMARK_CONFIG = ANGIO2D_C / "configs" / "benchmark.yaml"
BIN_PATH = ANGIO2D_C / "build" / "angio2d"
OUTPUT_ROOT = ANGIO2D_C / "output"
OUTPUT_CSV_DIR = OUTPUT_ROOT / "csv"
OUTPUT_FIG_DIR = OUTPUT_ROOT / "figures"
DEFAULT_RESULTS_DIR = OUTPUT_ROOT
GRID_TO_INDEX = {64: 0, 128: 1, 256: 2, 512: 3}
VALIDATION_FIELDS = ["diagnostics_c", "solution_c_C", "solution_c_P", "solution_c_Inh", "solution_c_F"]


@dataclass
class RunResult:
    success: bool
    elapsed_s: float
    reason: str
    stdout: str
    stderr: str
    returncode: int


def _load_yaml(path: Path) -> dict:
    if yaml is not None:
        with path.open("r", encoding="utf-8") as f:
            return yaml.safe_load(f) or {}
    text = path.read_text(encoding="utf-8")
    lines = [line.split("#", 1)[0].rstrip() for line in text.splitlines()]
    cleaned = "\n".join(line for line in lines if line.strip())
    data = {}
    for line in cleaned.splitlines():
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        data[k.strip()] = v.strip()
    return data


def _python_exec() -> str:
    env_py = os.environ.get("ANGIO2D_PYTHON")
    if env_py:
        return env_py
    venv_py = ROOT / ".venv" / "bin" / "python"
    if venv_py.exists():
        return str(venv_py)
    return sys.executable


def _run(
    cmd: List[str],
    cwd: Path,
    env: Optional[Dict[str, str]] = None,
    timeout_s: Optional[int] = None,
) -> RunResult:
    start = time.time()
    try:
        proc = subprocess.run(
            cmd,
            cwd=str(cwd),
            env=env,
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
        )
        elapsed = time.time() - start
        if proc.returncode == 0:
            return RunResult(True, elapsed, "ok", proc.stdout, proc.stderr, proc.returncode)
        reason = "nonzero_exit"
        if "out of memory" in (proc.stderr or "").lower():
            reason = "oom_suspected"
        return RunResult(False, elapsed, reason, proc.stdout, proc.stderr, proc.returncode)
    except subprocess.TimeoutExpired as exc:
        elapsed = time.time() - start
        return RunResult(False, elapsed, "timeout", exc.stdout or "", exc.stderr or "", 124)


def _compile_backend(backend: str) -> None:
    if backend == "serial":
        res = _run(["make", "clean"], ANGIO2D_C)
        if not res.success:
            raise RuntimeError(f"Build clean failed: {res.stderr[:240]}")
        res = _run(["make", "USE_OPENMP=0"], ANGIO2D_C)
    elif backend == "openmp":
        res = _run(["make", "clean"], ANGIO2D_C)
        if not res.success:
            raise RuntimeError(f"Build clean failed: {res.stderr[:240]}")
        res = _run(["make", "USE_OPENMP=1"], ANGIO2D_C)
    else:
        raise ValueError(f"Unsupported backend: {backend}")
    if not res.success or not BIN_PATH.exists():
        raise RuntimeError(f"Compile {backend} failed: {res.stderr[:240]}")


def _csv_values(path: Path) -> List[float]:
    vals: List[float] = []
    if not path.exists():
        return vals
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s:
            continue
        try:
            vals.append(float(s))
        except ValueError:
            continue
    return vals


def _rel_l2(a: List[float], b: List[float]) -> float:
    if not a or not b or len(a) != len(b):
        return math.inf
    diff_sq = sum((x - y) ** 2 for x, y in zip(a, b))
    norm_sq = sum(x * x for x in a)
    if norm_sq <= 0.0:
        return 0.0
    return math.sqrt(diff_sq / norm_sq)


def _copy_tree(src: Path, dst: Path) -> None:
    if dst.exists():
        shutil.rmtree(dst)
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(src, dst)


def _run_solver(grid: int, backend: str, threads: Optional[int], timeout_s: int) -> RunResult:
    if grid not in GRID_TO_INDEX:
        return RunResult(False, 0.0, "bad_grid", "", f"Unsupported grid size {grid}", 2)
    env = os.environ.copy()
    env["OMP_PROC_BIND"] = env.get("OMP_PROC_BIND", "close")
    env["OMP_PLACES"] = env.get("OMP_PLACES", "cores")
    env["OMP_DYNAMIC"] = env.get("OMP_DYNAMIC", "FALSE")
    if backend == "openmp" and threads is not None:
        env["OMP_NUM_THREADS"] = str(threads)
    cmd = [
        str(BIN_PATH),
        "--config",
        str(BENCHMARK_CONFIG),
        "--grid-index",
        str(GRID_TO_INDEX[grid]),
    ]
    return _run(cmd, ANGIO2D_C, env=env, timeout_s=timeout_s)


def _generate_plots() -> RunResult:
    return _run([_python_exec(), "scripts/plot_results.py"], ANGIO2D_C)


def _config_name(grid: int, threads: int) -> str:
    return f"{grid}x{grid}-{threads}threads"


def _prepare_run_dir(base_output: Path, grid: int, threads: int, run_id: Optional[int]) -> Path:
    cfg_dir = base_output / _config_name(grid, threads)
    if run_id is None:
        run_dir = cfg_dir
    else:
        run_dir = cfg_dir / f"run-{run_id:03d}"
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "csv").mkdir(parents=True, exist_ok=True)
    (run_dir / "figures").mkdir(parents=True, exist_ok=True)
    return run_dir


def _write_log(path: Path, payload: str) -> None:
    path.write_text(payload, encoding="utf-8")


def _extract_elapsed_s(log_text: str) -> Optional[float]:
    match = re.search(r"elapsed_s=([0-9]*\.?[0-9]+)", log_text)
    if not match:
        return None
    return float(match.group(1))


def _build_speedup_summary(output_dir: Path, grids: List[int], threads: List[int]) -> None:
    summary_rows: List[dict] = []
    best_rows: List[str] = []

    for grid in grids:
        per_thread: Dict[int, List[float]] = {}
        failures: Dict[int, int] = {}
        for thread in threads:
            cfg_dir = output_dir / _config_name(grid, thread)
            run_dirs = sorted([p for p in cfg_dir.glob("run-*") if p.is_dir()])
            if not run_dirs and (cfg_dir / "log.txt").exists():
                run_dirs = [cfg_dir]

            elapsed_vals: List[float] = []
            fail_count = 0
            for run_dir in run_dirs:
                log_file = run_dir / "log.txt"
                if not log_file.exists():
                    continue
                text = log_file.read_text(encoding="utf-8")
                if "success=True" not in text:
                    fail_count += 1
                    continue
                elapsed = _extract_elapsed_s(text)
                if elapsed is not None:
                    elapsed_vals.append(elapsed)

            per_thread[thread] = elapsed_vals
            failures[thread] = fail_count

        baseline_vals = per_thread.get(1, [])
        baseline_median = median(baseline_vals) if baseline_vals else None
        best_speedup = -1.0
        best_thread = None

        for thread in threads:
            vals = per_thread.get(thread, [])
            if not vals:
                summary_rows.append(
                    {
                        "grid": f"{grid}x{grid}",
                        "threads": thread,
                        "runs_ok": 0,
                        "runs_failed": failures.get(thread, 0),
                        "time_mean_s": "",
                        "time_median_s": "",
                        "speedup_vs_t1": "",
                        "efficiency_pct": "",
                    }
                )
                continue

            t_mean = mean(vals)
            t_median = median(vals)
            speedup = (baseline_median / t_median) if baseline_median and t_median > 0 else None
            efficiency = (speedup / thread * 100.0) if speedup is not None else None
            if speedup is not None and speedup > best_speedup:
                best_speedup = speedup
                best_thread = thread

            summary_rows.append(
                {
                    "grid": f"{grid}x{grid}",
                    "threads": thread,
                    "runs_ok": len(vals),
                    "runs_failed": failures.get(thread, 0),
                    "time_mean_s": f"{t_mean:.6f}",
                    "time_median_s": f"{t_median:.6f}",
                    "speedup_vs_t1": "" if speedup is None else f"{speedup:.4f}",
                    "efficiency_pct": "" if efficiency is None else f"{efficiency:.2f}",
                }
            )

        if best_thread is not None and best_speedup > 0:
            best_rows.append(f"- {grid}x{grid}: best speedup {best_speedup:.2f}x @ {best_thread} threads")
        else:
            best_rows.append(f"- {grid}x{grid}: no valid runs")

    csv_path = output_dir / "openmp_speedup_summary.csv"
    md_path = output_dir / "openmp_speedup_summary.md"
    fieldnames = [
        "grid",
        "threads",
        "runs_ok",
        "runs_failed",
        "time_mean_s",
        "time_median_s",
        "speedup_vs_t1",
        "efficiency_pct",
    ]
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    with md_path.open("w", encoding="utf-8") as f:
        f.write("# OpenMP Speedup Summary\n\n")
        f.write("| Grid | Threads | OK Runs | Failed | Mean (s) | Median (s) | Speedup vs t=1 | Efficiency (%) |\n")
        f.write("|---|---:|---:|---:|---:|---:|---:|---:|\n")
        for row in summary_rows:
            f.write(
                f"| {row['grid']} | {row['threads']} | {row['runs_ok']} | {row['runs_failed']} | "
                f"{row['time_mean_s'] or '-'} | {row['time_median_s'] or '-'} | "
                f"{row['speedup_vs_t1'] or '-'} | {row['efficiency_pct'] or '-'} |\n"
            )
        f.write("\n## Best Per Grid\n")
        for line in best_rows:
            f.write(f"{line}\n")


def _run_validation_for_current_output(
    grid: int,
    backend: str,
    threads: Optional[int],
    timeout_s: int,
    run_dir: Path,
) -> str:
    _compile_backend("serial")
    serial_res = _run_solver(grid, "serial", None, timeout_s)
    if not serial_res.success:
        _compile_backend(backend)
        return "validation: serial baseline failed"

    serial_snapshot = run_dir / "_serial_baseline_tmp"
    _copy_tree(OUTPUT_CSV_DIR, serial_snapshot)

    _compile_backend(backend)
    target_res = _run_solver(grid, backend, threads, timeout_s)
    if not target_res.success:
        return f"validation: target rerun failed ({target_res.reason})"

    lines = ["validation_rel_l2:"]
    for field in VALIDATION_FIELDS:
        aval = _csv_values(serial_snapshot / f"{field}.csv")
        bval = _csv_values(OUTPUT_CSV_DIR / f"{field}.csv")
        rel = _rel_l2(aval, bval)
        lines.append(f"  {field}: {rel:.6e}")
    shutil.rmtree(serial_snapshot, ignore_errors=True)
    return "\n".join(lines)


def _persist_outputs(run_dir: Path, generate_plots: bool) -> str:
    _copy_tree(OUTPUT_CSV_DIR, run_dir / "csv")
    if generate_plots:
        pres = _generate_plots()
        if not pres.success:
            return f"plot: failed ({pres.reason})"
        _copy_tree(OUTPUT_FIG_DIR, run_dir / "figures")
    return "plot: ok"


def _single_run(
    grid: int,
    threads: int,
    backend: str,
    validate: bool,
    generate_plots: bool,
    output_dir: Path,
    timeout_s: int,
) -> int:
    run_dir = _prepare_run_dir(output_dir, grid, threads, run_id=None)
    _compile_backend(backend)
    result = _run_solver(grid, backend, threads if backend == "openmp" else None, timeout_s)

    lines = [
        f"grid={grid}",
        f"threads={threads}",
        f"backend={backend}",
        f"success={result.success}",
        f"reason={result.reason}",
        f"elapsed_s={result.elapsed_s:.6f}",
        "",
        "stdout:",
        result.stdout,
        "",
        "stderr:",
        result.stderr,
    ]
    if not result.success:
        _write_log(run_dir / "log.txt", "\n".join(lines))
        print(f"Run failed: {result.reason}")
        return 1

    lines.append("")
    lines.append(_persist_outputs(run_dir, generate_plots))
    if validate:
        lines.append(
            _run_validation_for_current_output(
                grid,
                backend,
                threads if backend == "openmp" else None,
                timeout_s,
                run_dir,
            )
        )
        _persist_outputs(run_dir, generate_plots)

    _write_log(run_dir / "log.txt", "\n".join(lines))
    print(f"Single pipeline completed in: {run_dir}")
    return 0


def run_benchmark_from_profile(config: dict, output_dir: Path) -> int:
    backend = str(config.get("backend", "openmp"))
    grid_sizes = [int(x) for x in config.get("grid_sizes", [64, 128, 256])]
    threads = [int(x) for x in config.get("threads", [1, 2, 4])]
    runs = int(config.get("runs", 3))
    validate = bool(config.get("validate_against_serial", True))
    generate_plots = bool(config.get("generate_plots", True))
    timeout_s = int(config.get("timeout_per_run", 600))
    continue_on_failure = bool(config.get("continue_on_failure", True))

    output_dir.mkdir(parents=True, exist_ok=True)
    failures = 0

    for grid in grid_sizes:
        for thread in threads:
            for run_id in range(1, runs + 1):
                run_dir = _prepare_run_dir(output_dir, grid, thread, run_id=run_id)
                _compile_backend(backend)
                run_res = _run_solver(grid, backend, thread if backend == "openmp" else None, timeout_s)

                lines = [
                    f"grid={grid}",
                    f"threads={thread}",
                    f"backend={backend}",
                    f"run={run_id}",
                    f"success={run_res.success}",
                    f"reason={run_res.reason}",
                    f"elapsed_s={run_res.elapsed_s:.6f}",
                    "",
                    "stdout:",
                    run_res.stdout,
                    "",
                    "stderr:",
                    run_res.stderr,
                ]

                if run_res.success:
                    lines.append("")
                    lines.append(_persist_outputs(run_dir, generate_plots))
                    if validate:
                        lines.append(
                            _run_validation_for_current_output(
                                grid,
                                backend,
                                thread if backend == "openmp" else None,
                                timeout_s,
                                run_dir,
                            )
                        )
                        _persist_outputs(run_dir, generate_plots)
                else:
                    failures += 1
                    if not continue_on_failure:
                        _write_log(run_dir / "log.txt", "\n".join(lines))
                        raise RuntimeError(
                            f"Benchmark aborted at grid={grid}, threads={thread}, run={run_id} ({run_res.reason})"
                        )
                _write_log(run_dir / "log.txt", "\n".join(lines))

    _build_speedup_summary(output_dir=output_dir, grids=grid_sizes, threads=threads)
    return 0 if failures == 0 else 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ANGIO2D unified pipeline runner")
    parser.add_argument("--grid", type=int, help="Grid size (64, 128, 256)")
    parser.add_argument("--threads", type=int, help="OpenMP threads")
    parser.add_argument("--runs", type=int, default=None, help="Number of benchmark runs")
    parser.add_argument("--backend", choices=["openmp", "serial"], default="openmp")
    parser.add_argument("--config", type=str, help="YAML benchmark profile")
    parser.add_argument("--validate", action="store_true", help="Enable validation checks")
    parser.add_argument("--generate-plots", action="store_true", help="Generate final solver figures")
    parser.add_argument("--output-dir", type=str, default=None, help="Output directory override")
    parser.add_argument("--timeout-per-run", type=int, default=600)
    parser.add_argument("--continue-on-failure", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.config:
        cfg_path = Path(args.config)
        if not cfg_path.is_absolute():
            cfg_path = ROOT / cfg_path
        if not cfg_path.exists():
            raise FileNotFoundError(f"Config not found: {cfg_path}")
        config = _load_yaml(cfg_path)
        if args.runs is not None:
            config["runs"] = args.runs
        if args.output_dir:
            config["output_dir"] = args.output_dir
        if args.continue_on_failure:
            config["continue_on_failure"] = True
        outdir = Path(config.get("output_dir", str(DEFAULT_RESULTS_DIR)))
        if not outdir.is_absolute():
            outdir = ROOT / outdir
        if args.grid is not None:
            config["grid_sizes"] = [args.grid]
        if args.threads is not None:
            config["threads"] = [args.threads]
        if args.validate:
            config["validate_against_serial"] = True
        if args.generate_plots:
            config["generate_plots"] = True
        return run_benchmark_from_profile(config, outdir)

    if args.grid is None:
        raise SystemExit("Single-run mode requires --grid, or pass --config for batch mode.")

    outdir = Path(args.output_dir) if args.output_dir else DEFAULT_RESULTS_DIR
    if not outdir.is_absolute():
        outdir = ROOT / outdir
    threads = args.threads if args.threads is not None else 1
    return _single_run(
        grid=args.grid,
        threads=threads,
        backend=args.backend,
        validate=args.validate,
        generate_plots=args.generate_plots or True,
        output_dir=outdir,
        timeout_s=args.timeout_per_run,
    )


if __name__ == "__main__":
    raise SystemExit(main())
