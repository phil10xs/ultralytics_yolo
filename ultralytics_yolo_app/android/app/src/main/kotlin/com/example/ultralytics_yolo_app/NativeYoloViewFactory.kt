package com.example.ultralytics_yolo_app

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeYoloViewFactory(
  private val lifecycleOwnerProvider: () -> LifecycleOwner
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    @Suppress("UNCHECKED_CAST")
    val params = args as? Map<String, Any?> ?: emptyMap()
    return NativeYoloView(context, params, lifecycleOwnerProvider())
  }
}
