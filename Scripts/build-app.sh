#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

xcodegen generate

DERIVED="$ROOT_DIR/.build/xcode"
XCODEBUILD_SIGNING_ARGS=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  XCODEBUILD_SIGNING_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

XCODEBUILD_ARGS=(
  -project LimitLens.xcodeproj
  -scheme LimitLens
  -configuration Release
  -derivedDataPath "$DERIVED"
  -allowProvisioningUpdates
)
if [[ ${#XCODEBUILD_SIGNING_ARGS[@]} -gt 0 ]]; then
  XCODEBUILD_ARGS+=("${XCODEBUILD_SIGNING_ARGS[@]}")
fi
XCODEBUILD_ARGS+=(
  build
)

xcodebuild "${XCODEBUILD_ARGS[@]}"

APP_SRC="$DERIVED/Build/Products/Release/LimitLens.app"
APP_DST="$ROOT_DIR/dist/LimitLens.app"

rm -rf "$APP_DST"
mkdir -p "$ROOT_DIR/dist"
cp -R "$APP_SRC" "$APP_DST"
echo "Built $APP_DST"
