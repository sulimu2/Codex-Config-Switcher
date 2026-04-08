#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SVG_PATH="$ROOT_DIR/Design/bridge-switch-app-icon.svg"
PNG_PATH="$ROOT_DIR/Design/bridge-switch-app-icon.png"
ICONSET_PATH="$ROOT_DIR/Support/Icon.iconset"
ICNS_PATH="$ROOT_DIR/Support/AppIcon.icns"

typeset -a python_candidates
python_candidates=()

for candidate in "$(command -v python3 2>/dev/null || true)" /Volumes/T1/Ai/conda/bin/python3 /opt/homebrew/bin/python3 /usr/bin/python3; do
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    python_candidates+=("$candidate")
  fi
done

typeset -U python_candidates

PYTHON_BIN=""
for candidate in $python_candidates; do
  user_site="$("$candidate" -m site --user-site 2>/dev/null || true)"
  if [[ -n "$user_site" ]]; then
    if PYTHONPATH="$user_site${PYTHONPATH:+:$PYTHONPATH}" DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib "$candidate" - <<'PY' >/dev/null 2>&1
import cairosvg
PY
    then
      PYTHON_BIN="$candidate"
      export PYTHONPATH="$user_site${PYTHONPATH:+:$PYTHONPATH}"
      break
    fi
  fi
done

if [[ -z "$PYTHON_BIN" ]]; then
  echo "Could not find a Python interpreter that can import cairosvg."
  echo "Current candidates: ${python_candidates[*]}"
  echo "Install it with: python3 -m pip install --user cairosvg"
  exit 1
fi

mkdir -p "$ICONSET_PATH"

DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib "$PYTHON_BIN" - <<PY
import cairosvg
from pathlib import Path

src = Path(r"$SVG_PATH")
out = Path(r"$PNG_PATH")
png_bytes = cairosvg.svg2png(url=str(src), output_width=1024, output_height=1024)
out.write_bytes(png_bytes)
print(f"Rendered transparent PNG: {out}")
PY

find "$ICONSET_PATH" -type f -name '*.png' -delete

sips -z 16 16 "$PNG_PATH" --out "$ICONSET_PATH/icon_16x16.png" >/dev/null
sips -z 32 32 "$PNG_PATH" --out "$ICONSET_PATH/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PNG_PATH" --out "$ICONSET_PATH/icon_32x32.png" >/dev/null
sips -z 64 64 "$PNG_PATH" --out "$ICONSET_PATH/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PNG_PATH" --out "$ICONSET_PATH/icon_128x128.png" >/dev/null
sips -z 256 256 "$PNG_PATH" --out "$ICONSET_PATH/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PNG_PATH" --out "$ICONSET_PATH/icon_256x256.png" >/dev/null
sips -z 512 512 "$PNG_PATH" --out "$ICONSET_PATH/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PNG_PATH" --out "$ICONSET_PATH/icon_512x512.png" >/dev/null
cp "$PNG_PATH" "$ICONSET_PATH/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_PATH" -o "$ICNS_PATH"

echo "Built icon assets:"
echo "$PNG_PATH"
echo "$ICNS_PATH"
