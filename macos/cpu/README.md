# macOS CPU-only setup (Public small model)

This setup runs MLC LLM natively on macOS using the CPU backend. It is useful
when you want to avoid Metal or compare CPU performance.

## What you get
- An isolated Python environment (conda) with MLC LLM installed.
- Local caches under `macos/cpu/cache/` for model weights and artifacts.
- A reproducible command log in `macos/cpu/commands.sh`.

## Prerequisites
- Conda (Miniconda or Anaconda).
- A Hugging Face token is optional. The default model is public and does not
  require authentication.

## Run
1. Open a terminal and `cd` into `macos/cpu`.
2. Update the model in `commands.sh` if desired. Default is
   `HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC`.
3. Execute `./commands.sh`.
4. To rebuild the conda environment from scratch, rerun with
   `FORCE_RECREATE=1 macos/cpu/commands.sh`.
5. To avoid reinstalling dependencies, add `SKIP_INSTALL=1`.
6. To only verify setup without launching the chat UI, add `SKIP_RUN=1`.

## Default behavior (no env vars)
- First run: installs deps and runs the chat.
- Later runs: skips install and runs the chat.

## Notes
- CPU-only inference can be slow for larger models. Consider a smaller model
  from `https://huggingface.co/mlc-ai` if latency is high.
- To use a gated model (e.g., Llama 3), install `huggingface_hub` and run
  `huggingface-cli login`, then set `MODEL=HF://mlc-ai/<model-id>`.
- Not purely env-local: `git lfs install` touches user/global git config, and
  caches/build outputs live under `macos/cpu/cache` and `build/`.
