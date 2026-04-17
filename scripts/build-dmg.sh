#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Codex Config Switcher"
APP_BUNDLE_PATH="$ROOT_DIR/dist/$APP_NAME.app"
INFO_PLIST_PATH="$ROOT_DIR/Support/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST_PATH")"
DMG_NAME="Codex-Config-Switcher-$VERSION.dmg"
DMG_PATH="$ROOT_DIR/dist/$DMG_NAME"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-config-switcher-dmg.XXXXXX")"

cleanup() {
  rm -rf "$STAGING_DIR"
}

trap cleanup EXIT

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

rm -f "$DMG_PATH"
ditto "$APP_BUNDLE_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "Built dmg at:"
echo "$DMG_PATH"
