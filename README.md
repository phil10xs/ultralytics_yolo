# Ultralytics Model Exports (YOLO11)

This directory contains the **model lifecycle** for the assignment:
- source checkpoint (`.pt`)
- reproducible export scripts
- generated mobile artifacts (`.tflite`, `.mlpackage`)

## Why exports are committed
For this assignment, exported artifacts are **committed intentionally** so reviewers can:
- build APK / iOS apps immediately
- inspect the exact binaries used for inference
- verify reproducibility by re-running the export scripts

### Production note
In a real CI/CD setup, exported binaries would **not** be committed.
They would be generated in CI or hosted via Git LFS / release assets.
This tradeoff is deliberate for ease of review.

---

## Prerequisites
- macOS / Linux
- Python **3.11**
- Virtual environment activated

---

## Setup

### 1. Create & activate venv
```bash
python3.11 -m venv .venv
source .venv/bin/activate
