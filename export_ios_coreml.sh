#!/usr/bin/env bash
set -euo pipefail

MODEL="yolo11n.pt"
IMG_SIZE=640

CANONICAL_DIR="../assets/models/ios"
RUNNER_DIR="../flutter_yolo_realtime/ios/Runner"

# Preconditions
[ -f "$MODEL" ] || { echo "Missing $MODEL. Run from ultralytics_models/"; exit 1; }
command -v yolo >/dev/null 2>&1 || { echo "yolo CLI not found"; exit 1; }

mkdir -p "$CANONICAL_DIR" "$RUNNER_DIR"

yolo export model="$MODEL" format=coreml imgsz="$IMG_SIZE"

MLPKG=""
for p in *.mlpackage; do
  [ -d "$p" ] && MLPKG="$p" && break
done

[ -n "$MLPKG" ] || { echo ".mlpackage not found"; exit 1; }

rm -rf "$CANONICAL_DIR/$MLPKG" "$RUNNER_DIR/$MLPKG"
cp -R "$MLPKG" "$CANONICAL_DIR/"
cp -R "$MLPKG" "$RUNNER_DIR/"

echo "iOS model ready:"
echo " - $CANONICAL_DIR/$MLPKG"
echo " - $RUNNER_DIR/$MLPKG"

echo ""
echo "One-time iOS step:"
echo "Add $MLPKG to Runner target (Copy Bundle Resources)."
echo "After that, re-running this script is sufficient."
