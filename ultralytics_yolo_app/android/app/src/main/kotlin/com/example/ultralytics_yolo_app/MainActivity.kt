package com.example.ultralytics_yolo_app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    // Register PlatformView for AndroidView(...)
    flutterEngine
      .platformViewsController
      .registry
      .registerViewFactory(
        "native_kotlin_yolo_view",
        NativeYoloViewFactory { this } // this = LifecycleOwner
      )
  }
}
