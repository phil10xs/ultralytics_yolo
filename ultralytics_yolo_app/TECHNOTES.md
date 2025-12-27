# TECHNOTES002 — Flutter + Native (Kotlin/Swift) Real-time YOLO11
Here’s a tightened but more technical version that explains how each goal is achieved, while staying brief and naming the key frameworks 


# Architecture & execution model
	•	3 execution paths: Flutter (bridge), Native Android (Kotlin), Native iOS (Swift) to validate parity across stacks.
	•	Flutter acts as orchestrator only; camera capture and inference live fully in native layers.
	•	Bounding boxes are produced in normalized space (0–1) and mapped to preview size in the overlay layer to avoid recomputation.

# Camera, inference & threading
	•	Android (Kotlin)
	•	CameraX ImageAnalysis with STRATEGY_KEEP_ONLY_LATEST
	•	Single-threaded executor + AtomicBoolean gate to prevent frame backlog
	•	TFLite Interpreter reused across frames, zero per-frame allocations
	•	iOS (Swift)
	•	AVFoundation capture pipeline
	•	CoreML via VNCoreMLRequest on a background queue
	•	Late frames dropped when inference is in-flight; UI updated on main thread only
	•	Flutter bridge
	•	Platform channels deliver structured results
	•	Dart side coalesces updates to prevent layout thrash and UI jank

# Overlay & rendering
	•	Overlays are decoupled from inference timing
	•	Rectangles rendered from normalized boxes → view coordinates
	•	Rendering uses lightweight Canvas / Core Graphics primitives only

# Lifecycle, safety & error handling
	•	Permission gating handled before pipeline startup (CameraX / AVAuthorizationStatus)
	•	Native cleanup is explicit:
	•	Android: ImageProxy.close(), executor shutdown, interpreter close
	•	iOS: stop capture session, release CoreML/Vision requests
	•	Missing or mis-bundled models surface clear runtime errors, never crashes

# Production-scale considerations
	•	Dynamic model & resolution scaling based on FPS and thermal state
	•	Structured performance logging (latency, FPS) with no PII
	•	Aspect-ratio & orientation–safe box mapping tests
	•	Defensive parsing for CoreML MLMultiArray outputs when Vision metadata is absent

