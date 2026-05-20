#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="${1:-$ROOT_DIR/dist/LimitLens.zip}"
PROFILE="${NOTARYTOOL_PROFILE:-LimitLens}"
STAPLED_ZIP="${ZIP_PATH%.zip}-notarized.zip"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required tool: $1" >&2
        exit 1
    fi
}

require_tool xcrun
require_tool ditto

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "Archive not found: $ZIP_PATH" >&2
    echo "Create it first with ./Scripts/archive-app.sh" >&2
    exit 1
fi

echo "Using notarytool keychain profile: $PROFILE"
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    cat >&2 <<EOF
Unable to use notarytool profile "$PROFILE".

Create it with:
  xcrun notarytool store-credentials "$PROFILE" --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>

Or set NOTARYTOOL_PROFILE to an existing profile name.
EOF
    exit 1
fi

xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$PROFILE" \
    --wait

PAYLOAD_DIR="$TMP_DIR/payload"
mkdir -p "$PAYLOAD_DIR"
ditto -x -k "$ZIP_PATH" "$PAYLOAD_DIR"

APP_PATH="$PAYLOAD_DIR/LimitLens.app"
if [[ ! -d "$APP_PATH" ]]; then
    APP_PATH="$(find "$PAYLOAD_DIR" -name 'LimitLens.app' -type d -maxdepth 3 -print -quit)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
    echo "LimitLens.app was not found in $ZIP_PATH" >&2
    exit 1
fi

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

rm -f "$STAPLED_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$STAPLED_ZIP"
echo "Created $STAPLED_ZIP"
