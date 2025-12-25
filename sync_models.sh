#!/usr/bin/env bash
set -euo pipefail

# Always run relative to the location of this script (repo root)
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODELS_DIR="$ROOT_DIR/ultralytics_models"

cd "$MODELS_DIR"

# Activate venv if present (optional convenience)
if [[ -f "$ROOT_DIR/.venv/bin/activate" ]]; then
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.venv/bin/activate"
elif [[ -f "$MODELS_DIR/.venv/bin/activate" ]]; then
  # shellcheck disable=SC1090
  source "$MODELS_DIR/.venv/bin/activate"
fi

# Run export scripts from repo root (where they actually live)
bash "$ROOT_DIR/export_android_tflite.sh"
bash "$ROOT_DIR/export_ios_coreml.sh"

echo "✅ Models exported + synced into app locations."
