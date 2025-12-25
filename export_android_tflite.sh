#!/usr/bin/env bash
set -euo pipefail

MODEL="yolo11n.pt"
IMG_SIZE=640

CANONICAL_DIR="../assets/models/android"
KOTLIN_ASSETS_DIR="../flutter_yolo_realtime/android/app/src/main/assets/models"
FLUTTER_ASSETS_DIR="../flutter_yolo_realtime/assets/models"

[ -f "$MODEL" ] || { echo "Missing $MODEL. Run from ultralytics_models/"; exit 1; }
command -v yolo >/dev/null 2>&1 || { echo "yolo CLI not found"; exit 1; }

mkdir -p "$CANONICAL_DIR" "$KOTLIN_ASSETS_DIR" "$FLUTTER_ASSETS_DIR"

echo "== Export FLOAT32 =="
yolo export model="$MODEL" format=tflite imgsz="$IMG_SIZE"

echo "== Export FP16 (if supported) =="
set +e
yolo export model="$MODEL" format=tflite imgsz="$IMG_SIZE" half=True
set -e

echo "== Export INT8 (if supported) =="
set +e
yolo export model="$MODEL" format=tflite imgsz="$IMG_SIZE" int8=True
set -e

# Find latest saved_model-like dir (Ultralytics may name it variously)
SAVED_MODEL_DIR="$(ls -dt *saved_model 2>/dev/null | head -n 1 || true)"
[ -n "$SAVED_MODEL_DIR" ] || { echo "saved_model directory not found"; exit 1; }

echo "Using export dir: $SAVED_MODEL_DIR"

copy_one () {
  local src="$1"
  local out="$2"
  if [ -f "$src" ]; then
    cp -f "$src" "$CANONICAL_DIR/$out"
    cp -f "$src" "$KOTLIN_ASSETS_DIR/$out"
    cp -f "$src" "$FLUTTER_ASSETS_DIR/$out"
    echo "Copied: $out"
  fi
}

# Prefer explicit names if present
FLOAT_SRC="$(ls "$SAVED_MODEL_DIR"/*float32*.tflite 2>/dev/null | head -n 1 || true)"
FP16_SRC="$(ls "$SAVED_MODEL_DIR"/*float16*.tflite 2>/dev/null | head -n 1 || true)"
INT8_SRC="$(ls "$SAVED_MODEL_DIR"/*_int8.tflite 2>/dev/null | head -n 1 || true)"

# If float32 not named, pick non-int8 non-fp16 as float fallback
if [ -z "$FLOAT_SRC" ]; then
  FLOAT_SRC="$(ls "$SAVED_MODEL_DIR"/*.tflite 2>/dev/null | grep -viE 'int8|float16' | head -n 1 || true)"
fi

copy_one "$FLOAT_SRC" "yolo11n_float32.tflite"
copy_one "$FP16_SRC"  "yolo11n_float16.tflite"
copy_one "$INT8_SRC"  "yolo11n_int8.tflite"

echo ""
echo "Android model copied to:"
echo " - $CANONICAL_DIR/"
echo " - $KOTLIN_ASSETS_DIR/"
echo " - $FLUTTER_ASSETS_DIR/"
echo ""
echo "Files now available (if exports succeeded):"
ls -1 "$FLUTTER_ASSETS_DIR" | grep -E 'yolo11n_.*\.tflite' || true
