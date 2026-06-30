#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SVG="$ROOT_DIR/assets/app-icon.svg"
ICONSET="$ROOT_DIR/assets/LocalFlow.iconset"
PNG="$ROOT_DIR/assets/app-icon-1024.png"
ICNS="$ROOT_DIR/assets/LocalFlow.icns"

if [[ ! -f "$SVG" ]]; then
  echo "Missing icon source: $SVG" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

sips -s format png "$SVG" --out "$PNG" >/dev/null

make_icon() {
  local size="$1"
  local scale="$2"
  local pixels=$((size * scale))
  local suffix=""
  if [[ "$scale" == "2" ]]; then
    suffix="@2x"
  fi

  sips -z "$pixels" "$pixels" "$PNG" --out "$ICONSET/icon_${size}x${size}${suffix}.png" >/dev/null
}

make_icon 16 1
make_icon 16 2
make_icon 32 1
make_icon 32 2
make_icon 128 1
make_icon 128 2
make_icon 256 1
make_icon 256 2
make_icon 512 1
make_icon 512 2

iconutil -c icns "$ICONSET" -o "$ICNS"

echo "Created $ICNS"
