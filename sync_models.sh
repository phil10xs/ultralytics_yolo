#!/usr/bin/env bash
set -euo pipefail

cd ultralytics_models

# Activate venv if present (optional convenience)
if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
fi

bash export_android_tflite.sh
bash export_ios_coreml.sh

echo "✅ Models exported + synced into app locations."
