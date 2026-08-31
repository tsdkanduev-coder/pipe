#!/usr/bin/env bash
# Build Sled on macOS 14+. This script is a no-op on Linux.
# Exact commands (also documented in README):
#
#   xcodebuild \
#     -project Dayflow/Dayflow.xcodeproj \
#     -scheme Dayflow \
#     -configuration Release \
#     -derivedDataPath build \
#     MACOSX_DEPLOYMENT_TARGET=14.0 \
#     CODE_SIGN_IDENTITY="" \
#     CODE_SIGNING_REQUIRED=NO \
#     CODE_SIGNING_ALLOWED=NO \
#     build
#
#   create-dmg \
#     --volname "Sled" \
#     --window-pos 200 120 \
#     --window-size 540 380 \
#     --icon-size 100 \
#     --app-drop-link 400 180 \
#     --icon "Sled.app" 140 180 \
#     "Sled.dmg" \
#     "build/Build/Products/Release/Sled.app"
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "S4 unmet on this host: $(uname -s) cannot produce a real Sled.app or Sled.dmg."
  echo "Run these exact commands on macOS 14+ with Xcode and create-dmg:"
  cat <<'EOF'

xcodebuild \
  -project Dayflow/Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Release \
  -derivedDataPath build \
  MACOSX_DEPLOYMENT_TARGET=14.0 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

create-dmg \
  --volname "Sled" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --app-drop-link 400 180 \
  --icon "Sled.app" 140 180 \
  "Sled.dmg" \
  "build/Build/Products/Release/Sled.app"

EOF
  exit 2
fi

xcodebuild \
  -project Dayflow/Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Release \
  -derivedDataPath build \
  MACOSX_DEPLOYMENT_TARGET=14.0 \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="build/Build/Products/Release/Sled.app"
if [[ ! -d "${APP_PATH}" ]]; then
  echo "ERROR: Built app not found at ${APP_PATH}" >&2
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not found. Install with: brew install create-dmg" >&2
  exit 1
fi

create-dmg \
  --volname "Sled" \
  --window-pos 200 120 \
  --window-size 540 380 \
  --icon-size 100 \
  --app-drop-link 400 180 \
  --icon "Sled.app" 140 180 \
  "Sled.dmg" \
  "${APP_PATH}"

echo "Built ${APP_PATH} and Sled.dmg"
