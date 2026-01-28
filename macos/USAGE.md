# macOS Metal/CPU 실행 가이드

이 문서는 `macos/metal`과 `macos/cpu` 스크립트를 기준으로 **네이티브 실행**하는 방법과
옵션을 정리합니다. 기본 모델은 공개된 `Qwen2.5-3B-Instruct`이며 토큰 없이 다운로드됩니다.

## 실행 방식 개요
- `macos/metal`: Metal(GPU)용 **wheel 기반** 실행 (소스 빌드 없음).
- `macos/cpu`: CPU-only **wheel 기반** 실행 (소스 빌드 없음).
- `macos/metal-dev`: **소스 빌드** (tvm-ffi, tvm, mlc-llm C++/Python) + Metal 실행.
- `macos/cpu-dev`: **소스 빌드** (tvm-ffi, tvm, mlc-llm C++/Python) + CPU 실행.

## Metal (GPU) 빠른 실행
```bash
cd macos/metal
chmod +x commands.sh
./commands.sh
```

## CPU-only 빠른 실행
```bash
cd macos/cpu
chmod +x commands.sh
./commands.sh
```

## 공통 옵션
- `ENV_NAME=...` : conda 환경 이름 지정
- `MODEL=HF://mlc-ai/<model-id>` : 기본 모델 변경
- `FORCE_RECREATE=1` : conda 환경 삭제 후 재생성
- `SKIP_INSTALL=1` : 패키지 설치 단계 건너뛰기
- `SKIP_RUN=1` : 모델 실행 단계 건너뛰기

예시:
```bash
ENV_NAME=mlc-llm-metal MODEL=HF://mlc-ai/phi-2-q4f16_1-MLC SKIP_INSTALL=1 \
  macos/metal/commands.sh
```

## 대표적인 사용 시나리오
### 1) 처음 설치 + 실행
```bash
macos/metal/commands.sh
macos/cpu/commands.sh
```

### 2) 설치 이후 재실행 (wheel 기반)
```bash
SKIP_INSTALL=1 macos/metal/commands.sh
SKIP_INSTALL=1 macos/cpu/commands.sh
```

### 3) dev 소스 빌드 후 테스트만
```bash
SKIP_INSTALL=1 RUN_CHAT=0 RUN_TESTS=1 macos/metal-dev/commands.sh
SKIP_INSTALL=1 RUN_CHAT=0 RUN_TESTS=1 macos/cpu-dev/commands.sh
```

### 4) dev 설치/빌드 완료 후 채팅만
```bash
SKIP_INSTALL=1 SKIP_PYTHON_INSTALL=1 SKIP_BUILD=1 RUN_TESTS=0 RUN_CHAT=1 \
  macos/metal-dev/commands.sh
SKIP_INSTALL=1 SKIP_PYTHON_INSTALL=1 SKIP_BUILD=1 RUN_TESTS=0 RUN_CHAT=1 \
  macos/cpu-dev/commands.sh
```

## Metal 소스 빌드 실행 (dev)
`macos/metal-dev`는 TVM과 MLC LLM을 소스에서 빌드해 사용하는 개발용 구성입니다.

```bash
cd macos/metal-dev
chmod +x commands.sh
./commands.sh
```

### metal-dev 기본 동작 (옵션 없이 실행)
- 첫 실행: 설치/빌드 진행 + 채팅 실행 (테스트는 기본으로 비활성).
- 재실행: 설치/빌드 건너뛰고 채팅만 실행.

### metal-dev 전용 옵션
- `CLEAN_BUILD=1` : `build/metal-dev`를 삭제하고 전체 재빌드
- `SKIP_PYTHON_INSTALL=1` : TVM/MLC editable 설치 생략
- `SKIP_BUILD=1` : CMake 빌드 생략 (기존 빌드 재사용, 없으면 경고 후 빌드)
- `SKIP_RUNTIME_DEPS=1` : 채팅/테스트에 필요한 최소 Python deps 설치 생략
- `FETCH_SUBMODULES=0` : TVM/Tokenizers/STB/XGrammar 서브모듈 가져오기 생략
- `RUN_TESTS=0` : 빌드 후 스모크 테스트 생략
- `RUN_CHAT=1` : 인터랙티브 채팅 실행
- `TEST_MODEL=HF://mlc-ai/<model-id>` : dev 테스트 모델 변경
- `LLVM_VERSION=15` : dev 환경에서 설치할 LLVM 버전 지정

## CPU 소스 빌드 실행 (dev)
`macos/cpu-dev`는 CPU-only 소스 빌드 환경입니다.

```bash
cd macos/cpu-dev
chmod +x commands.sh
./commands.sh
```

### cpu-dev 기본 동작 (옵션 없이 실행)
- 첫 실행: 설치/빌드 진행 + 채팅 실행 (테스트는 기본으로 비활성).
- 재실행: 설치/빌드 건너뛰고 채팅만 실행.

### cpu-dev 전용 옵션
- `CLEAN_BUILD=1` : `build/cpu-dev`를 삭제하고 전체 재빌드
- `SKIP_PYTHON_INSTALL=1` : TVM/MLC editable 설치 생략
- `SKIP_BUILD=1` : CMake 빌드 생략 (기존 빌드 재사용, 없으면 경고 후 빌드)
- `SKIP_RUNTIME_DEPS=1` : 채팅/테스트에 필요한 최소 Python deps 설치 생략
- `FETCH_SUBMODULES=0` : TVM/Tokenizers/STB/XGrammar 서브모듈 가져오기 생략
- `RUN_TESTS=0` : 빌드 후 스모크 테스트 생략
- `RUN_CHAT=1` : 인터랙티브 채팅 실행
- `TEST_MODEL=HF://mlc-ai/<model-id>` : dev 테스트 모델 변경
- `LLVM_VERSION=15` : dev 환경에서 설치할 LLVM 버전 지정

## 캐시 위치
- Metal: `macos/metal/cache/mlc_llm/`
- CPU: `macos/cpu/cache/mlc_llm/`
- Metal dev: `macos/metal-dev/cache/mlc_llm/`
- CPU dev: `macos/cpu-dev/cache/mlc_llm/`

모델을 지우려면 해당 경로 아래의 모델 디렉터리를 삭제하면 됩니다.

## 정리(clean) 스크립트
캐시와 빌드 산출물을 정리하려면 `macos/clean.sh`를 사용하세요.

```bash
# 전체 정리 (캐시 + build), 실행 전 확인
macos/clean.sh

# 실제 삭제
CONFIRM=1 macos/clean.sh

# 특정 대상만 정리
CONFIRM=1 TARGET=metal-dev macos/clean.sh

# 여러 대상을 쉼표로 지정
CONFIRM=1 TARGETS=metal,metal-dev macos/clean.sh

# 빌드만 / 캐시만 정리
CONFIRM=1 CLEAN_CACHE=0 macos/clean.sh
CONFIRM=1 CLEAN_BUILD=0 macos/clean.sh

# 삭제 없이 미리보기
DRY_RUN=1 macos/clean.sh

# conda 환경까지 삭제
CONFIRM=1 CLEAN_ENV=1 macos/clean.sh

# conda 환경 이름 오버라이드
CONFIRM=1 CLEAN_ENV=1 ENV_NAME_METAL=mlc-llm-metal ENV_NAME_CPU=mlc-llm-cpu \
  ENV_NAME_METAL_DEV=mlc-llm-metal-dev ENV_NAME_CPU_DEV=mlc-llm-cpu-dev macos/clean.sh
```

## CLI 사용 팁
- `>>>`는 입력 프롬프트입니다. 명령은 `>>> /help`처럼 입력합니다.
- `/exit`, `/reset`, `/stats` 등 특수 명령은 **줄 맨 앞에서** `/`로 시작해야 합니다.

## Llama‑3 Instruct 사용 시
Llama‑3 계열은 Hugging Face 접근 승인이 필요합니다. 승인 후 아래처럼 실행하세요.
```bash
MODEL=HF://mlc-ai/Llama-3-8B-Instruct-q4f16_1-MLC macos/metal/commands.sh
```
필요하면 `huggingface-cli login`으로 인증하세요.
