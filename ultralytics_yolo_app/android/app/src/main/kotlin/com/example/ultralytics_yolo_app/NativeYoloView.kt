package com.example.ultralytics_yolo_app

import android.content.Context
import android.view.View
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.platform.PlatformView

class NativeYoloView(
  ctx: Context,
  params: Map<String, Any?>,
  lifecycleOwner: LifecycleOwner
) : PlatformView {

  private val host = NativeKotlinYoloHostView(ctx)

  init {
    val inputSize = (params["inputSize"] as? Number)?.toInt() ?: 640
    val confThreshold = (params["confThreshold"] as? Number)?.toFloat() ?: 0.25f
    val iouThreshold = (params["iouThreshold"] as? Number)?.toFloat() ?: 0.45f
    val modelAsset = params["modelAsset"] as? String ?: "assets/models/yolo11n_int8.tflite"

    host.start(
      lifecycleOwner = lifecycleOwner,
      modelAsset = modelAsset,
      inputSize = inputSize,
      confThreshold = confThreshold,
      iouThreshold = iouThreshold
    )
  }

  override fun getView(): View = host

  override fun dispose() {
    host.stop()
  }
}
