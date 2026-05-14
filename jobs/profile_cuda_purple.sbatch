#!/bin/bash
#SBATCH --job-name=angio2d-cuda-profile
#SBATCH --partition=low-gn
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:20:00
#SBATCH --output=angio2d_c/output/_slurm/cuda_profile_%j.out
#SBATCH --error=angio2d_c/output/_slurm/cuda_profile_%j.err

set -euo pipefail

cd "$SLURM_SUBMIT_DIR"

mkdir -p angio2d_c/output/_slurm
mkdir -p angio2d_c/output/profiles

module purge || true
module load nvidia/cuda-12.8.0

export CUDA_HOME=/opt/share/libs/nvidia/cuda-12.8.0
export CUDA_PATH=$CUDA_HOME
export LD_LIBRARY_PATH="$CUDA_HOME/targets/x86_64-linux/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$CUDA_HOME/targets/x86_64-linux/lib:${LIBRARY_PATH:-}"
export CPATH="$CUDA_HOME/targets/x86_64-linux/include:${CPATH:-}"

source .venv/bin/activate

echo "Node: $(hostname)"
echo "Job ID: $SLURM_JOB_ID"
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"

nvidia-smi
which nvcc
nvcc --version

make -C angio2d_c cuda

nsys profile \
  --stats=true \
  --trace=cuda,nvtx,osrt \
  --force-overwrite=true \
  -o angio2d_c/output/profiles/cuda_profile_${SLURM_JOB_ID} \
  python scripts/run_batch.py --config configs/cuda_profile_quick.yaml --backend cuda

echo "Profiling completed"
