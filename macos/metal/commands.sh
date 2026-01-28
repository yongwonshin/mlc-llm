#!/usr/bin/env bash
set -euo pipefail

# Reproducible commands for running a public model with Metal on macOS.

cd "$(dirname "$0")"

# 0) Install Xcode Command Line Tools (required for Metal compilation).
xcode-select --install || true

# 1) Create and activate a dedicated conda environment.
ENV_NAME="${ENV_NAME:-mlc-llm-metal}"
if ! command -v conda >/dev/null 2>&1; then
  echo "conda is required. Install Miniconda/Anaconda first." >&2
  exit 1
fi
source "$(conda info --base)/etc/profile.d/conda.sh"
ENV_BASE="$(conda info --base)"
ENV_PATH="${ENV_BASE}/envs/${ENV_NAME}"
NEW_ENV_CREATED=0
ENV_INCOMPLETE=0
if [ "${FORCE_RECREATE:-0}" = "1" ] && [ -d "${ENV_PATH}" ]; then
  echo "Removing existing conda env: ${ENV_PATH}"
  rm -rf "${ENV_PATH}"
fi
if [ -d "${ENV_PATH}" ] && [ ! -d "${ENV_PATH}/conda-meta" ]; then
  echo "Directory exists but is not a conda environment: ${ENV_PATH}" >&2
  echo "Delete it or rerun with FORCE_RECREATE=1" >&2
  exit 1
fi
if [ -d "${ENV_PATH}/conda-meta" ]; then
  if [ -d "${ENV_PATH}/.condatmp" ]; then
    echo "Warning: ${ENV_PATH}/.condatmp exists; env may be incomplete." >&2
    ENV_INCOMPLETE=1
  fi
  echo "Reusing existing conda env: ${ENV_PATH}"
  conda activate "${ENV_PATH}"
else
  if conda env list | awk '{print $1}' | grep -q "^${ENV_NAME}$"; then
    echo "Reusing existing conda env: ${ENV_NAME}"
  else
    conda create -y -n "${ENV_NAME}" python=3.13
    NEW_ENV_CREATED=1
  fi
  conda activate "${ENV_NAME}"
fi

# Default to skipping installs on reruns unless explicitly overridden.
if [ -z "${SKIP_INSTALL+x}" ]; then
  if [ "${NEW_ENV_CREATED}" = "1" ] || [ "${ENV_INCOMPLETE}" = "1" ]; then
    SKIP_INSTALL=0
  else
    SKIP_INSTALL=1
  fi
fi

# Ensure we use the installed wheel, not a local source checkout.
unset PYTHONPATH

# 2) Install dependencies (skip with SKIP_INSTALL=1).
if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  conda install -y -c conda-forge git-lfs
  git lfs install

  # 3) Install MLC LLM nightly (Metal-compatible wheel).
  python -m pip install --pre -U -f https://mlc.ai/wheels \
    mlc-llm-nightly-cpu \
    mlc-ai-nightly-cpu
else
  echo "Skipping dependency install (SKIP_INSTALL=1)"
fi

# 4) Keep caches local to this folder for reproducibility.
export MLC_LLM_HOME="${PWD}/cache/mlc_llm"
export HF_HOME="${PWD}/cache/hf"
mkdir -p "${MLC_LLM_HOME}" "${HF_HOME}"

# 5) Run a public, small model on Metal (no token required).
if [ "${SKIP_RUN:-0}" = "1" ]; then
  echo "Skipping model run (SKIP_RUN=1)"
  exit 0
fi
MODEL="${MODEL:-HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC}"
python -m mlc_llm chat "${MODEL}" --device metal
