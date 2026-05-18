#!/usr/bin/env python3
"""Collect CUDA environment metadata for reproducible ANGIO2D runs."""

from __future__ import annotations

import argparse
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path


def _run(cmd: list[str]) -> dict:
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return {
            "cmd": " ".join(cmd),
            "returncode": proc.returncode,
            "stdout": proc.stdout.strip(),
            "stderr": proc.stderr.strip(),
        }
    except FileNotFoundError:
        return {"cmd": " ".join(cmd), "returncode": 127, "stdout": "", "stderr": "command not found"}


def main() -> int:
    parser = argparse.ArgumentParser(description="CUDA environment check for ANGIO2D phase3")
    parser.add_argument(
        "--output",
        default="angio2d_c/output/_meta/cuda_env_report.json",
        help="Output JSON report path",
    )
    args = parser.parse_args()

    report = {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "checks": [
            _run(["nvidia-smi"]),
            _run(["nvcc", "--version"]),
            _run(["bash", "-lc", "module avail cuda"]),
            _run(["bash", "-lc", "ldconfig -p | grep -i cusparse"]),
        ],
    }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(str(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
