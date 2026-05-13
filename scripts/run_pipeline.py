#!/usr/bin/env python3
"""Deprecated wrapper.

Use:
  - scripts/run_simulation.py  (single run)
  - scripts/run_batch.py       (batch from config)
"""

from __future__ import annotations

import sys


def main() -> int:
    if "--config" in sys.argv:
        from run_batch import main as batch_main

        print(
            "DEPRECATION WARNING: 'run_pipeline.py --config ...' is deprecated. "
            "Use 'scripts/run_batch.py --config ...'.",
            file=sys.stderr,
        )
        return batch_main()

    from run_simulation import main as sim_main

    print(
        "DEPRECATION WARNING: 'run_pipeline.py' is deprecated. "
        "Use 'scripts/run_simulation.py'.",
        file=sys.stderr,
    )
    return sim_main()


if __name__ == "__main__":
    raise SystemExit(main())
