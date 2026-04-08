#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Config Switcher"
BUNDLE_PATH="$ROOT_DIR/dist/$APP_NAME.app"
EXECUTABLE_PATH="$ROOT_DIR/.build/release/CodexConfigSwitcher"

swift build -c release --package-path "$ROOT_DIR" --product CodexConfigSwitcher

rm -rf "$BUNDLE_PATH"
mkdir -p "$BUNDLE_PATH/Contents/MacOS" "$BUNDLE_PATH/Contents/Resources"

cp "$EXECUTABLE_PATH" "$BUNDLE_PATH/Contents/MacOS/CodexConfigSwitcher"
cp "$ROOT_DIR/Support/Info.plist" "$BUNDLE_PATH/Contents/Info.plist"
if [[ -f "$ROOT_DIR/Support/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Support/AppIcon.icns" "$BUNDLE_PATH/Contents/Resources/AppIcon.icns"
fi
chmod +x "$BUNDLE_PATH/Contents/MacOS/CodexConfigSwitcher"

codesign --force --deep --sign - "$BUNDLE_PATH" >/dev/null 2>&1 || true

echo "Built app bundle at:"
echo "$BUNDLE_PATH"
