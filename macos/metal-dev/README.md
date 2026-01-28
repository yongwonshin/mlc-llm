# macOS Metal dev setup (source build)

This setup builds TVM and MLC LLM from source and runs them on Metal. It uses a
dedicated conda environment to avoid conflicts with the wheel-based setups.

## What you get
- A `mlc-llm-metal-dev` conda environment (default name).
- Build artifacts under `build/metal-dev` (incremental by default).
- Local caches under `macos/metal-dev/cache/`.

## Quick run
```bash
cd macos/metal-dev
chmod +x commands.sh
./commands.sh
```

## Default behavior (no env vars)
- First run: installs deps, builds from source, and launches chat (tests off).
- Later runs: skips install/build and launches chat only.

## Options
- `ENV_NAME=...` : conda environment name (default: `mlc-llm-metal-dev`).
- `FORCE_RECREATE=1` : delete and recreate the conda env.
- `CLEAN_BUILD=1` : remove `build/metal-dev` and rebuild from scratch.
- `SKIP_INSTALL=1` : skip dependency installation steps.
- `SKIP_PYTHON_INSTALL=1` : skip editable installs for TVM/MLC.
- `SKIP_BUILD=1` : skip CMake configure/build (reuse existing artifacts).
- `SKIP_RUNTIME_DEPS=1` : skip minimal Python runtime deps (numpy/prompt_toolkit/etc.).
- `FETCH_SUBMODULES=0` : skip fetching git submodules (default is on).
- `RUN_TESTS=0` : skip smoke tests (default is on).
- `RUN_CHAT=1` : launch interactive chat after build (default off).
- `MODEL=HF://mlc-ai/<model-id>` : model used for interactive chat.
- `TEST_MODEL=HF://mlc-ai/<model-id>` : override the default test model.
- `LLVM_VERSION=15` : LLVM version to install (default is 15).

## Notes
- Incremental build is the default; set `CLEAN_BUILD=1` for a full rebuild.
- To reuse an existing build without reinstalling Python packages, set
  `SKIP_BUILD=1 SKIP_PYTHON_INSTALL=1`. If required build artifacts are missing,
  the script warns and rebuilds anyway.
- This script validates that the active conda env path matches `ENV_NAME` to
  avoid collisions with other environments.
- Required submodules: `3rdparty/tvm`, `3rdparty/tokenizers-cpp`, `3rdparty/stb`,
  `3rdparty/xgrammar`.
- The script installs only minimal Python deps for smoke tests. Install full
  dependencies with `python -m pip install -r python/requirements.txt` if needed.
- The default test model is `Qwen2.5-3B-Instruct` and does not require gated
  access. Use `TEST_MODEL` to override with Llama-3 if needed.
- LLVM 21+ can cause Metal JIT failures. Recreate the env with
  `FORCE_RECREATE=1 LLVM_VERSION=15` if you see compiler errors.
- If you see `RegisterOpAttr` or `runtime-only TVM` errors, ensure
  `build/metal-dev/tvm/libtvm.dylib` exists and rerun with `CLEAN_BUILD=1`.
