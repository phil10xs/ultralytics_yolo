# Flutter — Real-time YOLO11 Object Detection (On-device)

This Flutter project performs **real-time YOLO11 object detection on a live camera feed using local models** (no remote API).
It includes **three modes**:

1. **Flutter YOLO** — Ultralytics `ultralytics_yolo` plugin.
2. **Native Kotlin YOLO** — Android PlatformView (CameraX + TFLite).
3. **Native Swift YOLO** — iOS PlatformView (AVFoundation + CoreML/Vision).

## Model download + export

### Download YOLO11 weights
- https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt

### Export (requires Python)
```bash
pip install ultralytics
```

**Android (TFLite INT8)**
```bash
yolo export model=yolo11n.pt format=tflite imgsz=640 int8=True
```
Copy output (e.g. `yolo11n_int8.tflite`) to:
```
assets/models/yolo11n_int8.tflite
```

**iOS (CoreML .mlpackage)**
```bash
yolo export model=yolo11n.pt format=coreml imgsz=640
```
Copy output (e.g. `yolo11n.mlpackage`) to:
```
ios/Runner/yolo11n.mlpackage
```
Open Xcode and ensure it’s in **Copy Bundle Resources**.

## Run
```bash
flutter pub get
flutter run
```
