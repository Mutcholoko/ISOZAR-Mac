#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/XGDTool"
BUILD="$ROOT/build/xgdtool"
BREW_PREFIX="$(brew --prefix)"

if [[ ! -d "$VENDOR/.git" ]]; then
  mkdir -p "$ROOT/vendor"
  git clone --recursive https://github.com/wiredopposite/XGDTool.git "$VENDOR"
else
  git -C "$VENDOR" submodule update --init --recursive
fi

if ! command -v pkg-config >/dev/null 2>&1; then
  echo "Install the XGDTool build dependencies first: brew install cmake pkgconf lz4 zstd openssl curl wxwidgets" >&2
  exit 1
fi

# XGDTool's CMake currently replaces PKG_CONFIG_PATH with /usr/local/lib/pkgconfig,
# which is the Intel Homebrew path. Prepend Apple Silicon Homebrew metadata while
# retaining any pkg-config paths already configured by the user.
export PKG_CONFIG_PATH="$BREW_PREFIX/lib/pkgconfig:$BREW_PREFIX/opt/lz4/lib/pkgconfig:$BREW_PREFIX/opt/zstd/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

# Homebrew ships this metadata as liblz4.pc, while this upstream CMake
# requests the filename lz4.pc despite the package's internal name being lz4.
if [[ -f "$BREW_PREFIX/lib/pkgconfig/liblz4.pc" && ! -f "$BREW_PREFIX/lib/pkgconfig/lz4.pc" ]]; then
  mkdir -p "$ROOT/build/pkgconfig"
  ln -sf "$BREW_PREFIX/lib/pkgconfig/liblz4.pc" "$ROOT/build/pkgconfig/lz4.pc"
  export PKG_CONFIG_PATH="$ROOT/build/pkgconfig:$PKG_CONFIG_PATH"
fi

# The current upstream CMakeLists.txt resets the variable to /usr/local,
# which is incorrect on Apple Silicon. Patch only the local dependency checkout.
python3 - "$VENDOR/CMakeLists.txt" "$BREW_PREFIX" <<'PY'
from pathlib import Path
import sys

cmake_file = Path(sys.argv[1])
brew_prefix = sys.argv[2]
source = cmake_file.read_text()
source = source.replace(
    'set(ENV{PKG_CONFIG_PATH} "/usr/local/lib/pkgconfig:$ENV{PKG_CONFIG_PATH}")',
    f'set(ENV{{PKG_CONFIG_PATH}} "{brew_prefix}/lib/pkgconfig:{brew_prefix}/opt/lz4/lib/pkgconfig:$ENV{{PKG_CONFIG_PATH}}")',
)
cmake_file.write_text(source)
PY

# Apple Silicon's libc++ uses a size_t type that differs from upstream's
# uint64_t alias here, so std::min cannot infer a shared template type.
python3 - "$VENDOR/src/ImageWriter" <<'PY'
from pathlib import Path
import sys

for filename in ("CCIWriter/CCIWriter.cpp", "CSOWriter/CSOWriter.cpp"):
    source_file = Path(sys.argv[1]) / filename
    source = source_file.read_text()
    source = source.replace(
        "std::min(bytes_remaining, read_buffer.size())",
        "std::min(bytes_remaining, static_cast<uint64_t>(read_buffer.size()))",
    )
    source_file.write_text(source)
PY

pkg-config --exists lz4 || {
  echo "pkg-config cannot find LZ4. Verify it is installed with: brew install lz4" >&2
  exit 1
}

cmake -S "$VENDOR" -B "$BUILD" -DENABLE_GUI=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD" --config Release --parallel

mkdir -p "$ROOT/Resources"
cp "$BUILD/XGDTool" "$ROOT/Resources/XGDTool"
chmod +x "$ROOT/Resources/XGDTool"
echo "Built converter: $ROOT/Resources/XGDTool"
