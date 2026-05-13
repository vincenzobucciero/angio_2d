#!/bin/bash
#SBATCH --job-name=angio_openmp_bench
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=angio2d_c/output/_slurm/slurm_%j.out
#SBATCH --error=angio2d_c/output/_slurm/slurm_%j.err
#SBATCH --partition=default

# =========================================================
# ANGIO2D OpenMP Benchmark SLURM Job
# =========================================================
#
# This script runs the complete OpenMP benchmark suite
# for ANGIO2D on a compute node.
#
# To submit:
#   sbatch jobs/run_openmp_benchmark.sbatch
#   # Or with custom config:
#   sbatch -d singleton jobs/run_openmp_benchmark.sbatch
#
# To monitor:
#   squeue -u $USER
#   tail -f logs/benchmark_*.log
#
# =========================================================

set -euo pipefail

# Detect project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create log directory
mkdir -p "$PROJECT_ROOT/angio2d_c/output/_slurm"

# =========================================================
# Load modules (adjust for your cluster)
# =========================================================

# If your cluster uses modules, uncomment and customize:
# module load gcc/11
# module load python/3.9

# =========================================================
# Set OpenMP environment variables
# =========================================================

export OMP_PROC_BIND=close
export OMP_PLACES=cores
export OMP_DYNAMIC=FALSE

# For debugging/tuning (uncomment if needed):
# export OMP_DISPLAY_ENV=verbose

# =========================================================
# Print job info
# =========================================================

echo "=========================================="
echo "ANGIO2D OpenMP Benchmark Job"
echo "=========================================="
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $(hostname)"
echo "CPUs: $SLURM_CPUS_PER_TASK"
echo "Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Time: $(date)"
echo ""
echo "Environment:"
echo "  OMP_PROC_BIND=$OMP_PROC_BIND"
echo "  OMP_PLACES=$OMP_PLACES"
echo "  OMP_DYNAMIC=$OMP_DYNAMIC"
echo ""

# =========================================================
# Run benchmark
# =========================================================

cd "$PROJECT_ROOT"

# Default config
CONFIG="${1:-configs/openmp_benchmark.yaml}"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config not found: $CONFIG"
    exit 1
fi

echo "Config: $CONFIG"
echo "Running: python3 scripts/run_openmp_benchmark_from_config.py --config $CONFIG"
echo ""

python3 scripts/run_openmp_benchmark_from_config.py --config "$CONFIG"

BENCHMARK_EXIT=$?

# =========================================================
# Summary
# =========================================================

echo ""
echo "=========================================="
echo "Job completed with exit code: $BENCHMARK_EXIT"
echo "Time: $(date)"
echo ""
echo "Results saved to:"
echo "  Run outputs: angio2d_c/output/<grid>x<grid>-<threads>threads[/run-XXX]/"
echo "  SLURM logs: angio2d_c/output/_slurm/"
echo "=========================================="

exit $BENCHMARK_EXIT
