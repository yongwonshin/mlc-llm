# macOS Metal setup (Public small model)

This setup runs MLC LLM natively on macOS to access the Metal GPU. Docker
containers on macOS cannot access Metal, so GPU execution must be native.

## What you get
- An isolated Python environment (conda) with MLC LLM installed.
- Local caches under `macos/metal/cache/` for model weights and artifacts.
- A reproducible command log in `macos/metal/commands.sh`.

## Prerequisites
- Xcode Command Line Tools (required for Metal compilation).
- Conda (Miniconda or Anaconda).
- A Hugging Face token is optional. The default model is public and does not
  require authentication.

## Run
1. Open a terminal and `cd` into `macos/metal`.
2. Update the model in `commands.sh` if desired. Default is
   `HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC`.
3. Execute `./commands.sh`.
4. To rebuild the conda environment from scratch, rerun with
   `FORCE_RECREATE=1 macos/metal/commands.sh`.
5. To reuse an existing environment, just rerun `macos/metal/commands.sh`
   without `FORCE_RECREATE`.
6. To avoid reinstalling dependencies, add `SKIP_INSTALL=1`.
7. To only verify setup without launching the chat UI, add `SKIP_RUN=1`.

## Default behavior (no env vars)
- First run: installs deps and runs the chat.
- Later runs: skips install and runs the chat.

## Notes
- First run will download weights and JIT-compile Metal kernels; this can take
  several minutes.
- To use a gated model (e.g., Llama 3), install `huggingface_hub` and run
  `huggingface-cli login`, then set `MODEL=HF://mlc-ai/<model-id>`.
- Not purely env-local: `xcode-select --install` is system-level, `git lfs install`
  touches user/global git config, and caches/build outputs live under
  `macos/metal/cache` and `build/`.
