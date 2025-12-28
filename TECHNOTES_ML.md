# TECHNOTES001 - TECHNOTES with the tooling clarified 

# Model strategy (Hybrid)
Canonical models live in:
	•	assets/models/android/
	•	assets/models/ios/

They are copied into platform runtime locations so the Flutter app runs immediately with native inference:
	•	Android (Kotlin): android/app/src/main/assets/models/
	•	iOS (Swift, via Flutter bridge): ios/Runner/

There is no standalone Swift app. Swift is used only as a native iOS component bridged into Flutter.


# iOS one-time requirement

CoreML .mlpackage files must be manually added to the Runner target once.

Steps:
	1.	Open ios/Runner.xcworkspace in Xcode
	2.	Drag <model>.mlpackage into Runner
	3.	Ensure:
	•	☑ Copy items if needed
	•	☑ Runner (Target Membership)
	4.	Verify under Build Phases → Copy Bundle Resources

Future exports overwrite the model automatically.



# Model export

Exports are generated via:
	•	export_android_tflite.sh
	•	export_ios_coreml.sh

Single entrypoint:
	•	tools/sync_models.sh

INT8 TFLite preferred; FP16 fallback.

⸻

# Tooling & workflow
	•	VS Code – primary workspace for Flutter + native bridge
	•	Android Studio – Kotlin / CameraX / TFLite debugging
	•	Xcode – Swift / CoreML integration and iOS signing

# VS Code
	•	Task “Sync YOLO models (Android + iOS)” runs sync_models.sh
	•	Launch config “Flutter: Run (sync models first)” runs the task before Flutter

Assessors should run via VS Code Run or execute the sync task first.

⸻

# Runtime notes
	•	Real-time camera streaming
	•	Inference runs off the UI thread
	•	Frame backpressure enabled
	•	UI rendering decoupled from inference
	•	Native Kotlin and Swift accessed only through the Flutter bridge

⸻