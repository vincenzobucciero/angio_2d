#!/bin/bash
# Deprecated wrapper kept for backward compatibility.
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_cuda.sbatch" "$@"
