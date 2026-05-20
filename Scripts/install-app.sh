#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="LimitLens.app"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME"

"$ROOT_DIR/Scripts/build-app.sh"

if [[ -w /Applications ]]; then
    DEST_DIR="/Applications"
else
    DEST_DIR="$HOME/Applications"
    mkdir -p "$DEST_DIR"
fi

INSTALLED_APP="$DEST_DIR/$APP_NAME"
WIDGET_EXTENSION="$INSTALLED_APP/Contents/PlugIns/LimitLensWidgetExtension.appex"
WIDGET_ID="com.limitlens.dashboard.widget"
APP_BUNDLE_ID="com.limitlens.dashboard"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
registered_widget_paths=()
registered_app_paths=()

unregister_app_path() {
    local app_path="$1"
    [[ -z "$app_path" ]] && return

    if [[ -e "$app_path" ]]; then
        "$LSREGISTER" -u "$app_path" || true
        return
    fi

    case "$app_path" in
        */LimitLens.app)
            mkdir -p "$(dirname "$app_path")"
            cp -R "$SOURCE_APP" "$app_path"
            "$LSREGISTER" -u "$app_path" || true
            rm -rf "$app_path"
            ;;
    esac
}

pkill -x "LimitLens" || true
pkill -f "/LimitLensWidgetExtension.appex/Contents/MacOS/LimitLensWidgetExtension" || true

while IFS= read -r registered_path; do
    [[ -z "$registered_path" ]] && continue
    registered_widget_paths+=("$registered_path")
done < <(
    pluginkit -m -A -D -vvv -i "$WIDGET_ID" 2>/dev/null |
        awk -F' = ' '/^[[:space:]]*Path = / { print $2 }'
)

while IFS= read -r registered_app_path; do
    [[ -z "$registered_app_path" ]] && continue
    registered_app_paths+=("$registered_app_path")
done < <(
    "$LSREGISTER" -dump 2>/dev/null |
        awk -v bundle_id="$APP_BUNDLE_ID" '
            /^[[:space:]]*path:/ {
                path = $0
                sub(/^[[:space:]]*path:[[:space:]]*/, "", path)
            }
            /^[[:space:]]*identifier:/ && $2 == bundle_id && path != "" {
                print path
            }
        '
)

for registered_app_path in \
    "$INSTALLED_APP" \
    "$SOURCE_APP" \
    "$ROOT_DIR/.build/xcode/Build/Products/Release/$APP_NAME" \
    "${registered_app_paths[@]}"; do
    unregister_app_path "$registered_app_path"
done

for registered_path in "${registered_widget_paths[@]}"; do
    pluginkit -r "$registered_path" || true
done

"$LSREGISTER" -gc || true

rm -rf "$INSTALLED_APP"
cp -R "$SOURCE_APP" "$INSTALLED_APP"
touch "$INSTALLED_APP"

"$LSREGISTER" -f -R -trusted "$INSTALLED_APP"
pluginkit -a "$WIDGET_EXTENSION"
pluginkit -e use -i "$WIDGET_ID" || true
"$LSREGISTER" -f -R -trusted "$INSTALLED_APP"

echo "Installed $INSTALLED_APP"
