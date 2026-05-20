#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
ARCHIVE_PATH="$DIST_DIR/LimitLens.xcarchive"
EXPORT_DIR="$DIST_DIR/export"
EXPORT_OPTIONS="$DIST_DIR/ExportOptions.plist"
ZIP_PATH="$DIST_DIR/LimitLens.zip"
EXPORTED_APP="$EXPORT_DIR/LimitLens.app"

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcodegen
require_tool xcodebuild
require_tool ditto

cd "$ROOT_DIR"
mkdir -p "$DIST_DIR"
rm -rf "$ARCHIVE_PATH" "$EXPORT_DIR" "$ZIP_PATH" "$EXPORT_OPTIONS"

xcodegen generate

XCODEBUILD_SIGNING_ARGS=()
if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
    XCODEBUILD_SIGNING_ARGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

cat > "$EXPORT_OPTIONS" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>export</string>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
</dict>
</plist>
PLIST

ARCHIVE_ARGS=(
    -project LimitLens.xcodeproj
    -scheme LimitLens
    -configuration Release
    -destination "generic/platform=macOS"
    -archivePath "$ARCHIVE_PATH"
    -allowProvisioningUpdates
)
if [[ ${#XCODEBUILD_SIGNING_ARGS[@]} -gt 0 ]]; then
    ARCHIVE_ARGS+=("${XCODEBUILD_SIGNING_ARGS[@]}")
fi
ARCHIVE_ARGS+=(
    archive
)

xcodebuild "${ARCHIVE_ARGS[@]}"

EXPORT_ARGS=(
    -exportArchive
    -archivePath "$ARCHIVE_PATH"
    -exportPath "$EXPORT_DIR"
    -exportOptionsPlist "$EXPORT_OPTIONS"
    -allowProvisioningUpdates
)
if [[ ${#XCODEBUILD_SIGNING_ARGS[@]} -gt 0 ]]; then
    EXPORT_ARGS+=("${XCODEBUILD_SIGNING_ARGS[@]}")
fi

xcodebuild "${EXPORT_ARGS[@]}"

if [[ ! -d "$EXPORTED_APP" ]]; then
    echo "Expected exported app was not created: $EXPORTED_APP" >&2
    exit 1
fi

ditto -c -k --keepParent "$EXPORTED_APP" "$ZIP_PATH"
echo "Created $ZIP_PATH"
