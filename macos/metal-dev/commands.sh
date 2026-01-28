#!/usr/bin/env bash
set -euo pipefail

# Build and run MLC LLM + TVM from source on macOS Metal.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 0) Ensure Metal toolchain is available.
xcode-select --install || true

# 1) Create and activate a dedicated conda environment.
ENV_NAME="${ENV_NAME:-mlc-llm-metal-dev}"
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

if [ "${CONDA_PREFIX:-}" != "${ENV_PATH}" ]; then
  echo "Active conda env mismatch: ${CONDA_PREFIX} (expected ${ENV_PATH})" >&2
  exit 1
fi

if [ -z "${RUN_CHAT+x}" ]; then
  RUN_CHAT=1
fi
if [ -z "${RUN_TESTS+x}" ]; then
  RUN_TESTS=0
fi
if [ -z "${SKIP_INSTALL+x}" ]; then
  if [ "${NEW_ENV_CREATED}" = "1" ] || [ "${ENV_INCOMPLETE}" = "1" ]; then
    SKIP_INSTALL=0
  else
    SKIP_INSTALL=1
  fi
fi
if [ -z "${SKIP_PYTHON_INSTALL+x}" ]; then
  if [ "${NEW_ENV_CREATED}" = "1" ] || [ "${ENV_INCOMPLETE}" = "1" ]; then
    SKIP_PYTHON_INSTALL=0
  else
    SKIP_PYTHON_INSTALL=1
  fi
fi

unset PYTHONPATH
export PYTHONPATH="${REPO_ROOT}/python:${REPO_ROOT}/3rdparty/tvm/python"
TVM_SOURCE_DIR="${REPO_ROOT}/3rdparty/tvm"
TVM_FFI_SOURCE_DIR="${TVM_SOURCE_DIR}/3rdparty/tvm-ffi"
TOKENIZERS_SOURCE_DIR="${REPO_ROOT}/3rdparty/tokenizers-cpp"
STB_SOURCE_DIR="${REPO_ROOT}/3rdparty/stb"
XGRAMMAR_SOURCE_DIR="${REPO_ROOT}/3rdparty/xgrammar"

# Ensure TVM submodule is present (set FETCH_SUBMODULES=0 to skip).
if [ ! -d "${TVM_SOURCE_DIR}/python" ]; then
  if [ "${FETCH_SUBMODULES:-1}" = "1" ]; then
    git -C "${REPO_ROOT}" submodule update --init --recursive 3rdparty/tvm
  else
    echo "Missing TVM submodule at ${TVM_SOURCE_DIR}." >&2
    echo "Run: git submodule update --init --recursive 3rdparty/tvm" >&2
    exit 1
  fi
fi

if [ ! -f "${TOKENIZERS_SOURCE_DIR}/CMakeLists.txt" ]; then
  if [ "${FETCH_SUBMODULES:-1}" = "1" ]; then
    git -C "${REPO_ROOT}" submodule update --init --recursive 3rdparty/tokenizers-cpp
  else
    echo "Missing tokenizers-cpp submodule at ${TOKENIZERS_SOURCE_DIR}." >&2
    echo "Run: git submodule update --init --recursive 3rdparty/tokenizers-cpp" >&2
    exit 1
  fi
fi

if [ ! -f "${STB_SOURCE_DIR}/stb_image.h" ]; then
  if [ "${FETCH_SUBMODULES:-1}" = "1" ]; then
    git -C "${REPO_ROOT}" submodule update --init --recursive 3rdparty/stb
  else
    echo "Missing stb submodule at ${STB_SOURCE_DIR}." >&2
    echo "Run: git submodule update --init --recursive 3rdparty/stb" >&2
    exit 1
  fi
fi

if [ ! -f "${XGRAMMAR_SOURCE_DIR}/include/xgrammar/xgrammar.h" ]; then
  if [ "${FETCH_SUBMODULES:-1}" = "1" ]; then
    git -C "${REPO_ROOT}" submodule update --init --recursive 3rdparty/xgrammar
  else
    echo "Missing xgrammar submodule at ${XGRAMMAR_SOURCE_DIR}." >&2
    echo "Run: git submodule update --init --recursive 3rdparty/xgrammar" >&2
    exit 1
  fi
fi

# 2) Install build dependencies (skip with SKIP_INSTALL=1).
LLVM_VERSION="${LLVM_VERSION:-15}"
if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  conda install -y -c conda-forge \
    "llvmdev=${LLVM_VERSION}" \
    "cmake>=3.24" \
    git \
    git-lfs \
    rust
  git lfs install
else
  echo "Skipping dependency install (SKIP_INSTALL=1)"
fi

if command -v llvm-config >/dev/null 2>&1; then
  LLVM_CONFIG_MAJOR="$(llvm-config --version | cut -d. -f1)"
  if [ "${LLVM_CONFIG_MAJOR}" -ge 21 ]; then
    echo "Warning: LLVM ${LLVM_CONFIG_MAJOR} may break Metal JIT; consider LLVM_VERSION=15." >&2
  fi
fi

if [ "${SKIP_PYTHON_INSTALL:-0}" != "1" ]; then
  python -m pip install --upgrade pip
  if [ -f "${TVM_FFI_SOURCE_DIR}/pyproject.toml" ]; then
    python -m pip install -e "${TVM_FFI_SOURCE_DIR}"
  fi
  python -m pip install -e "${TVM_SOURCE_DIR}/python"
else
  echo "Skipping Python editable installs (SKIP_PYTHON_INSTALL=1)"
  echo "Ensure TVM/MLC Python packages are already installed." >&2
fi

# 3) Configure and build.
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build/metal-dev}"
if [ "${CLEAN_BUILD:-0}" = "1" ]; then
  echo "Removing build directory: ${BUILD_DIR}"
  rm -rf "${BUILD_DIR}"
fi
mkdir -p "${BUILD_DIR}"

if [ -z "${SKIP_BUILD+x}" ]; then
  if [ "${NEW_ENV_CREATED}" = "1" ] || [ "${ENV_INCOMPLETE}" = "1" ]; then
    SKIP_BUILD=0
  else
    BUILD_ARTIFACTS_PRESENT=1
    for lib_name in libtvm.dylib libmlc_llm_module.dylib; do
      if [ -z "$(find "${BUILD_DIR}" -name "${lib_name}" -not -path "*.dSYM/*" -print -quit)" ]; then
        BUILD_ARTIFACTS_PRESENT=0
        break
      fi
    done
    if [ "${BUILD_ARTIFACTS_PRESENT}" = "1" ]; then
      SKIP_BUILD=1
    else
      SKIP_BUILD=0
    fi
  fi
fi

SKIP_BUILD_EFFECTIVE="${SKIP_BUILD:-0}"
if [ "${SKIP_BUILD_EFFECTIVE}" = "1" ]; then
  MISSING_BUILD_ARTIFACTS=0
  for lib_name in libtvm.dylib libmlc_llm_module.dylib; do
    if [ -z "$(find "${BUILD_DIR}" -name "${lib_name}" -not -path "*.dSYM/*" -print -quit)" ]; then
      MISSING_BUILD_ARTIFACTS=1
      break
    fi
  done
  if [ "${MISSING_BUILD_ARTIFACTS}" = "1" ]; then
    echo "Warning: SKIP_BUILD=1 requested but build artifacts are missing in ${BUILD_DIR}; running build." >&2
    SKIP_BUILD_EFFECTIVE=0
  fi
fi

if [ "${SKIP_BUILD_EFFECTIVE}" != "1" ]; then
  CONFIG_FILE="${BUILD_DIR}/config.cmake"
  if [ ! -f "${CONFIG_FILE}" ] || [ "${CLEAN_BUILD:-0}" = "1" ]; then
    cat > "${CONFIG_FILE}" <<EOF
set(TVM_SOURCE_DIR ${TVM_SOURCE_DIR})
set(CMAKE_BUILD_TYPE RelWithDebInfo)
set(USE_LLVM "llvm-config --ignore-libllvm --link-static")
set(HIDE_PRIVATE_SYMBOLS ON)
set(BUILD_DUMMY_LIBTVM OFF)
set(USE_METAL ON)
set(USE_CUDA OFF)
set(USE_ROCM OFF)
set(USE_VULKAN OFF)
set(USE_OPENCL OFF)
EOF
  else
    if command -v rg >/dev/null 2>&1; then
      rg -q "BUILD_DUMMY_LIBTVM" "${CONFIG_FILE}" || echo "set(BUILD_DUMMY_LIBTVM OFF)" >> "${CONFIG_FILE}"
    else
      grep -q "BUILD_DUMMY_LIBTVM" "${CONFIG_FILE}" || echo "set(BUILD_DUMMY_LIBTVM OFF)" >> "${CONFIG_FILE}"
    fi
  fi

  NUM_THREADS="${NUM_THREADS:-$(sysctl -n hw.ncpu)}"
  CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}"
  cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" \
    -DCMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM}"
  cmake --build "${BUILD_DIR}" -j "${NUM_THREADS}"
else
  echo "Skipping build (SKIP_BUILD=1)"
fi

# 4) Runtime environment.
export MLC_LIBRARY_PATH="${BUILD_DIR}"
TVM_LIB_PATH="$(find "${BUILD_DIR}" -name "libtvm.dylib" -not -path "*.dSYM/*" -print -quit || true)"
TVM_RUNTIME_PATH="$(find "${BUILD_DIR}" -name "libtvm_runtime.dylib" -not -path "*.dSYM/*" -print -quit || true)"
if [ -n "${TVM_LIB_PATH}" ]; then
  export TVM_LIBRARY_PATH="$(dirname "${TVM_LIB_PATH}")"
  unset TVM_USE_RUNTIME_LIB
  export DYLD_LIBRARY_PATH="${TVM_LIBRARY_PATH}:${MLC_LIBRARY_PATH}:${DYLD_LIBRARY_PATH:-}"
elif [ -n "${TVM_RUNTIME_PATH}" ]; then
  echo "Error: libtvm.dylib not found; runtime-only TVM is insufficient for Relax." >&2
  echo "Run with CLEAN_BUILD=1 or check submodules/build output." >&2
  exit 1
else
  echo "Error: libtvm.dylib not found under ${BUILD_DIR}" >&2
  exit 1
fi

export MLC_LLM_HOME="${SCRIPT_DIR}/cache/mlc_llm"
export HF_HOME="${SCRIPT_DIR}/cache/hf"
mkdir -p "${MLC_LLM_HOME}" "${HF_HOME}"

if [ "${SKIP_PYTHON_INSTALL:-0}" != "1" ]; then
  python -m pip install -e "${REPO_ROOT}/python" --no-deps
fi

# 5) Runtime deps for chat/tests.
if [ "${SKIP_RUNTIME_DEPS:-0}" != "1" ]; then
  if [ "${RUN_TESTS:-1}" = "1" ] || [ "${RUN_CHAT:-0}" = "1" ]; then
    python -m pip install -q numpy pydantic shortuuid requests fastapi tqdm psutil \
      prompt_toolkit safetensors sentencepiece tiktoken
  fi
else
  echo "Skipping runtime deps (SKIP_RUNTIME_DEPS=1)"
fi

# 6) Smoke tests (default on).
if [ "${RUN_TESTS:-1}" = "1" ]; then
  TEST_SCRIPT="$(mktemp -t mlc-llm-metal-dev-test.XXXXXX.py)"
  cat > "${TEST_SCRIPT}" <<PY
from mlc_llm import MLCEngine


def main() -> None:
    # Create engine
    model = "${TEST_MODEL:-HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC}"
    engine = MLCEngine(model)

    # Run chat completion in OpenAI API.
    for response in engine.chat.completions.create(
        messages=[{"role": "user", "content": "What is the meaning of life?"}],
        model=model,
        stream=True,
    ):
        for choice in response.choices:
            print(choice.delta.content, end="", flush=True)
    print("\n")

    engine.terminate()


if __name__ == "__main__":
    main()
PY
  python "${TEST_SCRIPT}"
  rm -f "${TEST_SCRIPT}"
else
  echo "Skipping tests (RUN_TESTS=0)"
fi

# 7) Optional interactive chat.
if [ "${RUN_CHAT:-0}" = "1" ]; then
  MODEL="${MODEL:-HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC}"
  python -m mlc_llm chat "${MODEL}" --device metal
else
  echo "Skipping interactive chat (RUN_CHAT=0)"
fi
