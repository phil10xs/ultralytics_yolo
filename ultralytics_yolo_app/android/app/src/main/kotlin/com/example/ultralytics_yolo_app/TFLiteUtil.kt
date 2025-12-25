package com.example.ultralytics_yolo_app

import android.content.Context
import android.util.Log
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.MappedByteBuffer
import java.nio.channels.FileChannel

object TFLiteUtil {

  private const val TAG = "YoloTFLite"

  private fun log(msg: String) = Log.d(TAG, msg)
  private fun warn(msg: String) = Log.w(TAG, msg)
  private fun err(msg: String, t: Throwable? = null) {
    if (t != null) Log.e(TAG, msg, t) else Log.e(TAG, msg)
  }

  fun loadModelFromFlutterAssets(context: Context, assetPath: String): Interpreter {
    val cleaned = assetPath
      .removePrefix("flutter_assets/")
      .removePrefix("/")
      .trim()

    val full = if (cleaned.startsWith("assets/")) {
      "flutter_assets/$cleaned"
    } else {
      "flutter_assets/assets/$cleaned"
    }

    log("Loading TFLite model. dartPath='$assetPath' -> asset='$full'")

    return try {
      val fd = context.assets.openFd(full)
      FileInputStream(fd.fileDescriptor).use { input ->
        val channel: FileChannel = input.channel
        val mapped: MappedByteBuffer =
          channel.map(FileChannel.MapMode.READ_ONLY, fd.startOffset, fd.declaredLength)

        val interpreter = Interpreter(
          mapped,
          Interpreter.Options().apply { setNumThreads(4) }
        )

        runCatching {
          val inShape = interpreter.getInputTensor(0).shape().contentToString()
          val outShape = interpreter.getOutputTensor(0).shape().contentToString()
          log("TFLite loaded OK. inputShape=$inShape outputShape=$outShape")
        }.onFailure { e ->
          warn("Could not read tensor shapes: ${e.message}")
        }

        interpreter
      }
    } catch (t: Throwable) {
      err("Failed to load TFLite model from assets: $full", t)
      throw t
    }
  }
}
