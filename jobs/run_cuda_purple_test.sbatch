#!/bin/bash
#SBATCH --job-name=angio2d-cuda-test
#SBATCH --partition=low-gn
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:30:00
#SBATCH --output=angio2d_c/output/_slurm/cuda_test_%j.out
#SBATCH --error=angio2d_c/output/_slurm/cuda_test_%j.err

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"

mkdir -p angio2d_c/output/_slurm
mkdir -p angio2d_c/output/_meta

echo "Running on node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

module purge || true
module load nvidia/cuda-12.8.0

export CUDA_HOME=/opt/share/libs/nvidia/cuda-12.8.0
export CUDA_PATH=$CUDA_HOME
export LD_LIBRARY_PATH="$CUDA_HOME/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$CUDA_HOME/targets/x86_64-linux/lib:${LIBRARY_PATH:-}"
export CPATH="$CUDA_HOME/targets/x86_64-linux/include:${CPATH:-}"

echo "Checking GPU:"
nvidia-smi

echo "Checking CUDA compiler:"
which nvcc
nvcc --version

echo "Activating Python environment"
source .venv/bin/activate

echo "Checking CUDA from Python"
python scripts/check_cuda_env.py --output angio2d_c/output/_meta/cuda_env_report_${SLURM_JOB_ID}.json || true

echo "Building CUDA version"
make -C angio2d_c cuda

echo "Running CUDA benchmark"
python scripts/run_batch.py --config configs/cuda_benchmark_full.yaml --backend cuda

echo "CUDA test completed"
