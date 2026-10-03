#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/outputs/ISO to ZAR.app"

"$ROOT/Scripts/build-xgdtool.sh"
cd "$ROOT"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$ROOT/work/swift-cache" "$ROOT/work/clang-cache"
CLANG_MODULE_CACHE_PATH="$ROOT/work/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/work/clang-cache" \
swift build -c debug --scratch-path "$ROOT/work/swift-cache" --disable-sandbox || {
  echo "Swift app compilation failed. On managed macOS setups, SwiftPM's sandboxed macro compiler may be blocked; build with Xcode or allow swift-plugin-server to run." >&2
  exit 1
}
cp "$ROOT/work/swift-cache/debug/ZARConverter" "$APP/Contents/MacOS/ZARConverter"
cp "$ROOT/Resources/XGDTool" "$APP/Contents/Resources/XGDTool"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
echo "Created $APP"
