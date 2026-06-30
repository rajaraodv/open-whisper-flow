#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODEL_DIR="$ROOT_DIR/models/parakeet"
MODEL_VERSION="sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8"
ARCHIVE_NAME="$MODEL_VERSION.tar.bz2"
EXTRACTED_DIR="$MODEL_VERSION"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$ARCHIVE_NAME"

mkdir -p "$ROOT_DIR/models" "$MODEL_DIR"

if [[ -f "$MODEL_DIR/.model-version" ]] && [[ "$(cat "$MODEL_DIR/.model-version")" == "$MODEL_VERSION" ]] &&
   [[ -f "$MODEL_DIR/encoder.int8.onnx" && -f "$MODEL_DIR/decoder.int8.onnx" && -f "$MODEL_DIR/joiner.int8.onnx" && -f "$MODEL_DIR/tokens.txt" ]]; then
  echo "Parakeet model already exists at $MODEL_DIR"
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Downloading $URL"
curl -L --fail --progress-bar "$URL" -o "$TMP_DIR/$ARCHIVE_NAME"

echo "Extracting model"
tar -xjf "$TMP_DIR/$ARCHIVE_NAME" -C "$TMP_DIR"

cp "$TMP_DIR/$EXTRACTED_DIR/encoder.int8.onnx" "$MODEL_DIR/"
cp "$TMP_DIR/$EXTRACTED_DIR/decoder.int8.onnx" "$MODEL_DIR/"
cp "$TMP_DIR/$EXTRACTED_DIR/joiner.int8.onnx" "$MODEL_DIR/"
cp "$TMP_DIR/$EXTRACTED_DIR/tokens.txt" "$MODEL_DIR/"
printf "%s" "$MODEL_VERSION" > "$MODEL_DIR/.model-version"

echo "Installed Parakeet model to $MODEL_DIR"
