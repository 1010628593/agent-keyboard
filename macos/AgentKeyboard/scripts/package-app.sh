#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-debug}"
if [[ -d /Applications/Xcode-beta.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi
swift build --package-path "$ROOT" -c "$CONFIG" --product AgentKeyboard
BIN="$(swift build --package-path "$ROOT" -c "$CONFIG" --show-bin-path)/AgentKeyboard"
APP="$ROOT/.build/AgentKeyboard.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AgentKeyboard"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
BIN_DIR="$(dirname "$BIN")"
shopt -s nullglob
for bundle in "$BIN_DIR"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
# Prefer compiled .lproj next to the binary as well.
for lproj in "$BIN_DIR"/*.lproj; do
  cp -R "$lproj" "$APP/Contents/Resources/"
done

ICON_PNG="$ROOT/Resources/AppIcon.png"
ICON_ICNS="$ROOT/Resources/AppIcon.icns"
if [[ -f "$ICON_PNG" ]]; then
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z "$s" "$s" "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z "$((s * 2))" "$((s * 2))" "$ICON_PNG" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$ICON_ICNS"
  cp "$ICON_ICNS" "$APP/Contents/Resources/AppIcon.icns"
fi
echo "$APP"
