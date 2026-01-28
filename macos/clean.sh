#!/usr/bin/env bash
set -euo pipefail

# Clean macOS build artifacts and caches for wheel/dev workflows.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TARGETS="${TARGETS:-${TARGET:-all}}"
CLEAN_BUILD="${CLEAN_BUILD:-1}"
CLEAN_CACHE="${CLEAN_CACHE:-1}"
CLEAN_ENV="${CLEAN_ENV:-0}"
DRY_RUN="${DRY_RUN:-0}"
CONFIRM="${CONFIRM:-0}"

ENV_NAME_METAL="${ENV_NAME_METAL:-mlc-llm-metal}"
ENV_NAME_CPU="${ENV_NAME_CPU:-mlc-llm-cpu}"
ENV_NAME_METAL_DEV="${ENV_NAME_METAL_DEV:-mlc-llm-metal-dev}"
ENV_NAME_CPU_DEV="${ENV_NAME_CPU_DEV:-mlc-llm-cpu-dev}"

if [ -z "${TARGETS}" ]; then
  TARGETS="all"
fi

IFS=',' read -r -a TARGET_LIST <<< "${TARGETS}"

declare -a REMOVE_PATHS=()
declare -a REMOVE_ENVS=()
REMOVE_ENVS_COUNT=0

add_paths() {
  local target="$1"
  if [ "${CLEAN_CACHE}" = "1" ]; then
    case "${target}" in
      metal) REMOVE_PATHS+=("${REPO_ROOT}/macos/metal/cache") ;;
      cpu) REMOVE_PATHS+=("${REPO_ROOT}/macos/cpu/cache") ;;
      metal-dev) REMOVE_PATHS+=("${REPO_ROOT}/macos/metal-dev/cache") ;;
      cpu-dev) REMOVE_PATHS+=("${REPO_ROOT}/macos/cpu-dev/cache") ;;
    esac
  fi
  if [ "${CLEAN_BUILD}" = "1" ]; then
    case "${target}" in
      metal-dev) REMOVE_PATHS+=("${REPO_ROOT}/build/metal-dev") ;;
      cpu-dev) REMOVE_PATHS+=("${REPO_ROOT}/build/cpu-dev") ;;
    esac
  fi
}

add_env_name() {
  local env_name="$1"
  if [ "${REMOVE_ENVS_COUNT}" -gt 0 ]; then
    for existing in "${REMOVE_ENVS[@]}"; do
      if [ "${existing}" = "${env_name}" ]; then
        return 0
      fi
    done
  fi
  REMOVE_ENVS+=("${env_name}")
  REMOVE_ENVS_COUNT=$((REMOVE_ENVS_COUNT + 1))
}

add_envs() {
  local target="$1"
  case "${target}" in
    metal) add_env_name "${ENV_NAME_METAL}" ;;
    cpu) add_env_name "${ENV_NAME_CPU}" ;;
    metal-dev) add_env_name "${ENV_NAME_METAL_DEV}" ;;
    cpu-dev) add_env_name "${ENV_NAME_CPU_DEV}" ;;
  esac
}

for target in "${TARGET_LIST[@]}"; do
  case "${target}" in
    all)
      add_paths "metal"
      add_paths "cpu"
      add_paths "metal-dev"
      add_paths "cpu-dev"
      if [ "${CLEAN_ENV}" = "1" ]; then
        add_envs "metal"
        add_envs "cpu"
        add_envs "metal-dev"
        add_envs "cpu-dev"
      fi
      ;;
    metal|cpu|metal-dev|cpu-dev)
      add_paths "${target}"
      if [ "${CLEAN_ENV}" = "1" ]; then
        add_envs "${target}"
      fi
      ;;
    *)
      echo "Unknown TARGETS entry: ${target}" >&2
      echo "Use TARGETS=metal,cpu,metal-dev,cpu-dev or TARGET=all" >&2
      exit 1
      ;;
  esac
done

if [ "${#REMOVE_PATHS[@]}" -eq 0 ] && [ "${REMOVE_ENVS_COUNT}" -eq 0 ]; then
  echo "Nothing to remove. (CLEAN_BUILD=${CLEAN_BUILD}, CLEAN_CACHE=${CLEAN_CACHE}, CLEAN_ENV=${CLEAN_ENV})"
  exit 0
fi

echo "Planned removals:"
for path in "${REMOVE_PATHS[@]}"; do
  echo "  ${path}"
done
if [ "${REMOVE_ENVS_COUNT}" -gt 0 ]; then
  for env_name in "${REMOVE_ENVS[@]}"; do
    echo "  conda env: ${env_name}"
  done
fi

if [ "${DRY_RUN}" = "1" ]; then
  echo "Dry run only. Set CONFIRM=1 to remove."
  exit 0
fi

if [ "${CONFIRM}" != "1" ]; then
  echo "Not removing anything. Re-run with CONFIRM=1 to proceed."
  if [ "${CLEAN_ENV}" = "1" ]; then
    echo "CLEAN_ENV=1 is set; conda envs will also be removed with CONFIRM=1."
  else
    echo "To remove conda envs as well, add CLEAN_ENV=1."
  fi
  exit 0
fi

for path in "${REMOVE_PATHS[@]}"; do
  if [ -e "${path}" ]; then
    rm -rf "${path}"
  fi
done

if [ "${CLEAN_ENV}" = "1" ] && [ "${REMOVE_ENVS_COUNT}" -gt 0 ]; then
  if ! command -v conda >/dev/null 2>&1; then
    echo "conda not found; skipping env removal." >&2
  else
    for env_name in "${REMOVE_ENVS[@]}"; do
      if conda env list | awk '{print $1}' | grep -q "^${env_name}$"; then
        conda env remove -y -n "${env_name}"
      else
        echo "Conda env not found: ${env_name}"
      fi
    done
  fi
fi

echo "Clean complete."
