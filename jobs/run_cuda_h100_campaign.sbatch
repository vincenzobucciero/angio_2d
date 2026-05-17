#!/bin/bash
#SBATCH --job-name=angio2d-cuda-h100
#SBATCH --partition=h100gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=3-00:00:00
#SBATCH --output=results/h100_cuda_campaign/slurm_%j.out
#SBATCH --error=results/h100_cuda_campaign/slurm_%j.err

set -euo pipefail

ROOT_DIR="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
CONFIG_PATH="configs/h100_cuda_campaign.yaml"
CUDA_MODULE="${CUDA_MODULE:-nvidia/cuda-12.8.0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    *)
      CONFIG_PATH="$1"
      shift
      ;;
  esac
done

if [[ "${CONFIG_PATH}" != /* ]]; then
  CONFIG_PATH="${ROOT_DIR}/${CONFIG_PATH}"
fi
if [[ ! -f "${CONFIG_PATH}" ]]; then
  echo "Config file not found: ${CONFIG_PATH}" >&2
  exit 2
fi

mkdir -p "${ROOT_DIR}/results/h100_cuda_campaign"

if command -v module >/dev/null 2>&1; then
  module purge || true
  module load "${CUDA_MODULE}" || true
fi

export OMP_PROC_BIND="${OMP_PROC_BIND:-close}"
export OMP_PLACES="${OMP_PLACES:-cores}"
export OMP_DYNAMIC="${OMP_DYNAMIC:-FALSE}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
export ANGIO2D_CUDA_STRICT="${ANGIO2D_CUDA_STRICT:-1}"
export ANGIO2D_CUDA_PROFILE="${ANGIO2D_CUDA_PROFILE:-0}"
export ANGIO2D_DIAG_STRIDE="${ANGIO2D_DIAG_STRIDE:-256}"
export CUDA_NVCCFLAGS="${CUDA_NVCCFLAGS:--O3 -arch=sm_90}"

PYTHON_BIN="${ANGIO2D_PYTHON:-python3}"
GPU_GUARD_ENABLE="${GPU_GUARD_ENABLE:-1}"
GPU_GUARD_MIN_UTIL="${GPU_GUARD_MIN_UTIL:-3}"
GPU_GUARD_MIN_POWER_W="${GPU_GUARD_MIN_POWER_W:-70}"
GPU_GUARD_INTERVAL_S="${GPU_GUARD_INTERVAL_S:-5}"
GPU_GUARD_MAX_SAMPLES="${GPU_GUARD_MAX_SAMPLES:-120}" # 10 min @ 5s
GPU_GUARD_GRACE_S="${GPU_GUARD_GRACE_S:-90}"

cd "${ROOT_DIR}"
"${PYTHON_BIN}" scripts/check_cuda_env.py --output results/h100_cuda_campaign/cuda_env_report.json || true
make -C angio2d_c cuda

if [[ "${GPU_GUARD_ENABLE}" == "1" ]]; then
  echo "[GPU-GUARD] enabled (util>=${GPU_GUARD_MIN_UTIL}% or power>=${GPU_GUARD_MIN_POWER_W}W)"
  "${PYTHON_BIN}" scripts/run_batch.py --config "${CONFIG_PATH}" --backend cuda &
  BATCH_PID=$!
  sleep "${GPU_GUARD_GRACE_S}"

  gpu_active=0
  samples=0
  while kill -0 "${BATCH_PID}" 2>/dev/null && [[ "${samples}" -lt "${GPU_GUARD_MAX_SAMPLES}" ]]; do
    util="$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')"
    pwr="$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -1 | awk '{print int($1)}')"
    util="${util:-0}"
    pwr="${pwr:-0}"
    echo "[GPU-GUARD] sample=${samples} util=${util}% power=${pwr}W"
    if [[ "${util}" -ge "${GPU_GUARD_MIN_UTIL}" || "${pwr}" -ge "${GPU_GUARD_MIN_POWER_W}" ]]; then
      gpu_active=1
      echo "[GPU-GUARD] GPU activity detected, continuing benchmark."
      break
    fi
    sleep "${GPU_GUARD_INTERVAL_S}"
    samples=$((samples + 1))
  done

  if [[ "${gpu_active}" -eq 0 ]] && kill -0 "${BATCH_PID}" 2>/dev/null; then
    echo "[GPU-GUARD] ERROR: GPU remained idle in startup window. Aborting to avoid CPU-only long run."
    kill "${BATCH_PID}" 2>/dev/null || true
    wait "${BATCH_PID}" 2>/dev/null || true
    exit 99
  fi

  wait "${BATCH_PID}"
else
  "${PYTHON_BIN}" scripts/run_batch.py --config "${CONFIG_PATH}" --backend cuda
fi
