#!/usr/bin/env python3
from __future__ import annotations

import csv
import datetime
import math
import os
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "csv"
BASELINE = ROOT / "output" / "baseline_serial"
REPORT = ROOT / "output" / "csv" / "phase2_report.csv"

FIELDS = ["C", "P", "Inh", "F"]
THREADS = [1, 2, 3, 4]  # Focus on lower thread counts to find sweet spot
RUNS_PER_CASE = 5
TOL = 1e-6


def run_cmd(cmd: list[str], env: dict[str, str] | None = None) -> tuple[int, str]:
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, env=env)
    return proc.returncode, (proc.stdout + proc.stderr)


def run_solver(threads: int | None = None) -> tuple[float, str]:
    env = os.environ.copy()
    if threads is not None:
        env["OMP_NUM_THREADS"] = str(threads)
    # OPTIMIZATION: Set thread affinity for better scalability
    # OMP_PROC_BIND=close: Keep threads on nearby cores (same socket)
    # OMP_PLACES=cores: Bind to physical cores, not SMT threads
    # This reduces context switching and improves cache locality
    env["OMP_PROC_BIND"] = "close"
    env["OMP_PLACES"] = "cores"
    t0 = time.perf_counter()
    code, out = run_cmd([str(ROOT / "build" / "angio2d")], env=env)
    dt = time.perf_counter() - t0
    if code != 0:
        raise RuntimeError(out)
    return dt, out


def copy_outputs(dst_dir: Path) -> None:
    dst_dir.mkdir(parents=True, exist_ok=True)
    files = ["diagnostics_c.csv"] + [f"solution_c_{f}.csv" for f in FIELDS]
    for name in files:
        shutil.copy2(OUT / name, dst_dir / name)


def read_flat_csv(path: Path) -> list[float]:
    vals: list[float] = []
    with path.open("r", newline="") as f:
        reader = csv.reader(f)
        for row_idx, row in enumerate(reader):
            for cell in row:
                if cell.strip() == "":
                    continue
                # Skip header row (first row with non-numeric values)
                if row_idx == 0:
                    try:
                        float(cell)
                    except ValueError:
                        continue  # Skip this cell if it's part of the header
                vals.append(float(cell))
    return vals


def rel_l2(a: list[float], b: list[float]) -> float:
    if len(a) != len(b):
        return float("inf")
    num = 0.0
    den = 0.0
    for x, y in zip(a, b):
        d = x - y
        num += d * d
        den += y * y
    den = max(den, sys.float_info.epsilon)
    return math.sqrt(num / den)


def compare_against_baseline() -> dict[str, float]:
    metrics: dict[str, float] = {}

    diag_base = read_flat_csv(BASELINE / "diagnostics_c.csv")
    diag_new = read_flat_csv(OUT / "diagnostics_c.csv")
    metrics["diagnostics_rel_l2"] = rel_l2(diag_new, diag_base)

    for fld in FIELDS:
        base = read_flat_csv(BASELINE / f"solution_c_{fld}.csv")
        new = read_flat_csv(OUT / f"solution_c_{fld}.csv")
        metrics[f"field_{fld}_rel_l2"] = rel_l2(new, base)

    return metrics


def write_report(rows: list[dict[str, str]]) -> None:
    if not rows:
        return
    keys = list(rows[0].keys())
    with REPORT.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    start_time = datetime.datetime.now()
    print(f"[START] {start_time.isoformat()}")
    print("[1/5] Build serial baseline")
    code, out = run_cmd(["make", "clean"])
    if code != 0:
        print(out)
        return 1
    code, out = run_cmd(["make"])
    if code != 0:
        print(out)
        return 1

    print("[2/5] Run serial baseline")
    dt_baseline, _ = run_solver()
    print(f"serial baseline time: {dt_baseline:.3f}s")
    copy_outputs(BASELINE)

    print("[3/5] Build OpenMP")
    code, out = run_cmd(["make", "clean"])
    if code != 0:
        print(out)
        return 1
    code, out = run_cmd(["make", "USE_OPENMP=1"])
    if code != 0:
        print("OpenMP build failed on this machine.")
        print(out)
        return 2

    print("[4/5] Quick + Full")
    dt1, _ = run_solver(threads=1)
    print(f"openmp threads=1 time: {dt1:.3f}s (baseline: {dt_baseline:.3f}s, overhead: {(dt1/dt_baseline - 1.0)*100:+.1f}%)")
    metrics = compare_against_baseline()
    for k, v in metrics.items():
        print(f"{k}: {v:.6e}")

    if any(v > TOL for v in metrics.values()):
        print(f"FAIL: numerical drift above tolerance {TOL:.1e}")
        return 3

    print("[5/5] Stress benchmark")
    rows: list[dict[str, str]] = []
    times: dict[int, float] = {}

    for th in THREADS:
        samples = []
        for _ in range(RUNS_PER_CASE):
            t, _ = run_solver(threads=th)
            samples.append(t)
        med = statistics.median(samples)
        times[th] = med
        speedup = dt_baseline / med
        improvement_pct = (1.0 - med / dt_baseline) * 100.0
        rows.append({
            "threads": str(th),
            "median_seconds": f"{med:.6f}",
            "speedup_vs_baseline": f"{speedup:.3f}x",
            "improvement_percent": f"{improvement_pct:+.1f}%",
            "runs": str(RUNS_PER_CASE),
        })
        print(f"threads={th}: median={med:.4f}s speedup={speedup:.3f}x improvement={improvement_pct:+.1f}% samples={','.join(f'{x:.4f}' for x in samples)}")

    write_report(rows)

    base = times[1]
    speedup = max(base / times[t] for t in times if t > 1)
    print(f"best_speedup_vs_t1: {speedup:.3f}x")
    if speedup < 2.0:
        print("WARN: speedup target 2x not reached on this hardware/build.")
    else:
        print("PASS: speedup target reached.")
    
    end_time = datetime.datetime.now()
    elapsed = (end_time - start_time).total_seconds()
    print(f"[END] {end_time.isoformat()}")
    print(f"Total benchmark time: {elapsed:.1f}s")

    print(f"report saved: {REPORT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
