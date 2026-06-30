#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/ParaFlow.app"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
BACKEND_DIR="$RESOURCES_DIR/backend"
MODEL_SRC="$ROOT_DIR/models/parakeet"
MODEL_DST="$RESOURCES_DIR/models/parakeet"
PYTHON="$ROOT_DIR/.venv/bin/python"
VERSION="0.1.0"
DMG_PATH="$ROOT_DIR/dist/ParaFlow-$VERSION.dmg"
DMG_STAGE="$ROOT_DIR/.build/dmg-stage"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-}"

if [[ ! -x "$PYTHON" ]]; then
  echo "Missing .venv. Run: python3.12 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt" >&2
  exit 1
fi

if [[ ! -f "$MODEL_SRC/encoder.int8.onnx" ]]; then
  "$ROOT_DIR/scripts/download-parakeet-model.sh"
fi

"$ROOT_DIR/scripts/build-mac-app.sh"

if ! "$PYTHON" -m PyInstaller --version >/dev/null 2>&1; then
  "$PYTHON" -m pip install pyinstaller
fi

rm -rf "$BACKEND_DIR" "$MODEL_DST" "$ROOT_DIR/.build/pyinstaller"
mkdir -p "$BACKEND_DIR" "$MODEL_DST"

"$PYTHON" -m PyInstaller \
  --clean \
  --onefile \
  --name local-flow-worker \
  --distpath "$BACKEND_DIR" \
  --workpath "$ROOT_DIR/.build/pyinstaller/work" \
  --specpath "$ROOT_DIR/.build/pyinstaller" \
  "$ROOT_DIR/scripts/worker_entry.py"

cp "$MODEL_SRC/encoder.int8.onnx" "$MODEL_DST/"
cp "$MODEL_SRC/decoder.int8.onnx" "$MODEL_DST/"
cp "$MODEL_SRC/joiner.int8.onnx" "$MODEL_DST/"
cp "$MODEL_SRC/tokens.txt" "$MODEL_DST/"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  echo "Signing app with Developer ID identity: $CODESIGN_IDENTITY"
  codesign --force --deep --options runtime --timestamp --sign "$CODESIGN_IDENTITY" "$APP_DIR"
else
  echo "CODESIGN_IDENTITY is not set; using ad-hoc signing for local testing."
  codesign --force --deep --sign - "$APP_DIR"
fi

rm -rf "$DMG_STAGE"
mkdir -p "$DMG_STAGE"
cp -R "$APP_DIR" "$DMG_STAGE/"
ln -s /Applications "$DMG_STAGE/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "ParaFlow" \
  -srcfolder "$DMG_STAGE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$CODESIGN_IDENTITY" ]]; then
  echo "Signing DMG with Developer ID identity: $CODESIGN_IDENTITY"
  codesign --force --timestamp --sign "$CODESIGN_IDENTITY" "$DMG_PATH"
fi

if [[ -n "$NOTARY_KEYCHAIN_PROFILE" ]]; then
  echo "Submitting DMG for notarization with keychain profile: $NOTARY_KEYCHAIN_PROFILE"
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
else
  echo "NOTARY_KEYCHAIN_PROFILE is not set; skipping notarization."
fi

echo "Packaged $APP_DIR"
echo "Created $DMG_PATH"
