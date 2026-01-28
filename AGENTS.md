# Repository Guidelines

## Project Structure & Module Organization
MLC LLM spans multiple targets. Core runtime and engine code live in `cpp/`, while
the Python package and CLI are in `python/mlc_llm/`. Platform clients are split
across `android/`, `ios/`, and `web/`. Tests sit in `tests/python/` (pytest) and
`tests/cpp/` (gtest). Documentation lives in `docs/`, with sample apps in
`examples/`. Build helpers are under `cmake/`, CI scripts in `ci/`, and shared
dependencies in `3rdparty/` (submodules). Local build artifacts are typically
placed in a `build/` directory.

## Build, Test, and Development Commands
- `mkdir -p build && cd build && python ../cmake/gen_cmake_config.py` generates
  a `config.cmake` with platform-specific options.
- `cmake .. && make -j $(nproc)` builds `libmlc_llm` and related runtime libs.
- `pip install -e python` installs the Python package in editable mode.
- `python -m mlc_llm chat -h` is a quick CLI smoke check.
- `python -m pytest -v tests/python -m unittest` runs the fast Python unit set.
- `cmake -DBUILD_CPP_TEST=ON ..` then `./mlc_llm_cpp_tests` runs C++ gtests.

## Coding Style & Naming Conventions
Python code follows Black with a 100-character line length and 4-space indents;
imports are organized with isort. C++ formatting uses clang-format with the
Google style and a 100-column limit (`.clang-format`). CMake files can be
formatted with cmake-format via pre-commit. Favor descriptive names in public
APIs and keep module paths stable (e.g., `python/mlc_llm/model/...`).

## Testing Guidelines
Use pytest for Python coverage, adding `pytestmark = [pytest.mark.<category>]`
to classify tests (`unittest`, `op_correctness`, `engine`, `endpoint`). Some
categories require GPU hardware or model artifacts. C++ tests are named
`*unittest.cc` and are only built when `BUILD_CPP_TEST` is enabled.

### macOS workflows (wheel vs source)
- `macos/metal` / `macos/cpu`: wheel-based execution only (no source builds).
- `macos/metal-dev` / `macos/cpu-dev`: source builds of TVM-FFI (Python), TVM (C++ libs + Python),
  and MLC LLM (C++ libs + Python editable), then run on Metal/CPU respectively.
  `macos/metal-dev`/`macos/cpu-dev` default to first-run install/build + chat, and reruns skip install/build.

Common env vars:
- `FORCE_RECREATE=1` (recreate conda env), `SKIP_INSTALL=1` (skip deps),
  `SKIP_PYTHON_INSTALL=1` (skip editable installs), `SKIP_BUILD=1` (reuse build artifacts),
  `RUN_TESTS=0/1`, `RUN_CHAT=0/1`, `MODEL=...`, `TEST_MODEL=...`.

Representative use cases:
```bash
# 1) First run (wheel-based)
macos/metal/commands.sh
macos/cpu/commands.sh

# 2) Rerun after install (wheel-based)
SKIP_INSTALL=1 macos/metal/commands.sh
SKIP_INSTALL=1 macos/cpu/commands.sh

# 3) Dev build, tests only
SKIP_INSTALL=1 RUN_CHAT=0 RUN_TESTS=1 macos/metal-dev/commands.sh
SKIP_INSTALL=1 RUN_CHAT=0 RUN_TESTS=1 macos/cpu-dev/commands.sh

# 4) Dev chat only (after build/install complete)
SKIP_INSTALL=1 SKIP_PYTHON_INSTALL=1 SKIP_BUILD=1 RUN_TESTS=0 RUN_CHAT=1 \
  macos/metal-dev/commands.sh
SKIP_INSTALL=1 SKIP_PYTHON_INSTALL=1 SKIP_BUILD=1 RUN_TESTS=0 RUN_CHAT=1 \
  macos/cpu-dev/commands.sh
```

### macOS dev smoke test
For `macos/metal-dev` and `macos/cpu-dev`, validate the source build with a
non-interactive engine script (default model is public):

```python
from mlc_llm import MLCEngine


def main() -> None:
    # Create engine
    model = "HF://mlc-ai/Qwen2.5-3B-Instruct-q4f16_1-MLC"
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
```

## Commit & Pull Request Guidelines
Recent history uses short imperative subjects, often with bracketed scopes like
`[Python]` or `[Docs]` and optional PR numbers, e.g., `[Python] Fix FFI build
issue (#1234)` or `docs: update build notes`. Keep commits focused and avoid
mixing unrelated areas. PRs should include a concise summary, linked issues, and
the exact tests run (commands + environment details like OS/GPU when relevant).

## Documentation Sync
When changing macOS workflows or scripts, update both `macos/USAGE.md` and
`AGENTS.md` so local usage and contributor guidance stay aligned.
