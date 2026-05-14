#!/bin/bash
#SBATCH --job-name=angio2d_gpu_profile
#SBATCH --partition=low-gn
#SBATCH --gpus=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16GB
#SBATCH --time=00:30:00
#SBATCH --output=profiling_%j.log
#SBATCH --error=profiling_%j.err

set -e

# ============================================================================
# GPU PROFILING - ANGIO2D
# ============================================================================
# CUDA ADI Profiling on Tesla GPU nodes (gn01-02, gn04)
# - Responsibly limited to small/medium grids (64, 128, 256)
# - Generates detailed profiling reports
# - 30 minutes max runtime
# ============================================================================

PROJECT_DIR="/home/c.coppola/projects/angio_2d"
ANGIO2D_DIR="$PROJECT_DIR/angio2d_c"
RESULTS_DIR="$PROJECT_DIR/results/cuda_profiling"

echo "=========================================="
echo "ANGIO2D CUDA ADI Profiling"
echo "=========================================="
echo "Project: $PROJECT_DIR"
echo "Job ID: $SLURM_JOB_ID"
echo "Node: $SLURMD_NODENAME"
echo "GPU(s): $SLURM_GPUS"
echo "Time: $(date)"
echo "=========================================="
echo ""

# Load CUDA module if available
echo "Loading CUDA environment..."
if command -v module >/dev/null 2>&1; then
  module purge || true
  module load nvidia/cuda-12.8.0 2>/dev/null || echo "CUDA module not available (OK if CUDA already in PATH)"
fi

# Check CUDA availability
echo "Checking CUDA environment..."
echo "CUDA Version:"
nvcc --version || { echo "ERROR: nvcc not found"; exit 1; }
echo ""

# Create profiling directory
mkdir -p "$RESULTS_DIR"
cd "$PROJECT_DIR"

# Run Python profiling script
echo "Running CUDA profiling suite..."
python3 scripts/profile_cuda_adi.py --project-dir "$PROJECT_DIR"

PROF_RC=$?

echo ""
echo "=========================================="
echo "Profiling Complete (exit code: $PROF_RC)"
echo "=========================================="
echo "Results saved to: $RESULTS_DIR"
echo "Time: $(date)"
echo "=========================================="
echo ""

exit $PROF_RC
