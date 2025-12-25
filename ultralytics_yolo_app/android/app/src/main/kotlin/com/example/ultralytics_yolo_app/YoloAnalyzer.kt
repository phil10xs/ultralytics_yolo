package com.example.ultralytics_yolo_app

import android.graphics.Bitmap
import android.graphics.RectF
import android.os.SystemClock
import android.util.Log
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "YoloAnalyzer"

class YoloAnalyzer(
  private val interpreter: Interpreter,
  private val inputSize: Int,
  private val confThreshold: Float,
  private val iouThreshold: Float,
  private val onResult: (List<NativeKotlinYoloHostView.Detection>, Double, Double) -> Unit
) : ImageAnalysis.Analyzer {

  private val busy = AtomicBoolean(false)

  // FPS (smoothed)
  private var lastFrameNs = 0L
  private var fps = 0.0

  // Log throttling
  private var lastLogMs = 0L

  // Output shape cache
  private val outShape: IntArray = runCatching { interpreter.getOutputTensor(0).shape() }
    .getOrElse { intArrayOf(1, 84, 8400) }

  // Reused buffers
  private val inputBuffer: ByteBuffer =
    ByteBuffer.allocateDirect(inputSize * inputSize * 3 * 4).order(ByteOrder.nativeOrder())
  private val pixels = IntArray(inputSize * inputSize)

  // Reused output object
  private val outputObj: Any = allocateOutput(outShape)

  // ✅ Pure Kotlin postprocessor (returns RectN)
  private val post = YoloPostProcessor(labels = coco80)

  init {
    Log.d(TAG, "init inputSize=$inputSize conf=$confThreshold iou=$iouThreshold outShape=${outShape.contentToString()}")
  }

  override fun analyze(image: ImageProxy) {
    if (!busy.compareAndSet(false, true)) {
      image.close()
      return
    }

    val tAll0 = SystemClock.elapsedRealtimeNanos()

    try {
      // FPS
      val nowNs = SystemClock.elapsedRealtimeNanos()
      if (lastFrameNs != 0L) {
        val dtSec = (nowNs - lastFrameNs) / 1_000_000_000.0
        if (dtSec > 0) {
          val inst = 1.0 / dtSec
          fps = if (fps == 0.0) inst else (fps * 0.90 + inst * 0.10)
        }
      }
      lastFrameNs = nowNs

      // Convert
      val bmp = ImageConverters.imageProxyToBitmap(image)
      if (bmp == null) {
        onResult(emptyList(), fps, 0.0)
        return
      }

      // Preprocess
      val resized = Bitmap.createScaledBitmap(bmp, inputSize, inputSize, true)
      bitmapToFloatNHWC(resized, inputBuffer, pixels)

      // Inference
      val tInf0 = SystemClock.elapsedRealtimeNanos()
      interpreter.run(inputBuffer, outputObj)
      val inferMs = (SystemClock.elapsedRealtimeNanos() - tInf0) / 1_000_000.0

      // Decode (via pure Kotlin postprocessor)
      val out84N = to84xN(outputObj, outShape)
      val dets: List<NativeKotlinYoloHostView.Detection> =
        if (out84N == null) {
          emptyList()
        } else {
          post.decode84xN(out84N, confThreshold, iouThreshold, inputSize)
            .map { d ->
              // Convert pure Kotlin rect -> Android RectF for overlay
              NativeKotlinYoloHostView.Detection(
                RectF(d.rect.left, d.rect.top, d.rect.right, d.rect.bottom),
                d.label,
                d.score
              )
            }
        }

      onResult(dets, fps, inferMs)

      val allMs = (SystemClock.elapsedRealtimeNanos() - tAll0) / 1_000_000.0
      maybeLog("fps=${fmt(fps)} infer=${fmt(inferMs)}ms dets=${dets.size} all=${fmt(allMs)}ms")

    } catch (t: Throwable) {
      Log.e(TAG, "analyze() failed: ${t.message}", t)
      onResult(emptyList(), fps, 0.0)
    } finally {
      try { image.close() } catch (_: Throwable) {}
      busy.set(false)
    }
  }

  private fun maybeLog(msg: String) {
    val now = SystemClock.elapsedRealtime()
    if (now - lastLogMs >= 1000) {
      lastLogMs = now
      Log.d(TAG, msg)
    }
  }

  private fun fmt(v: Double) = String.format("%.1f", v)
}

/** NHWC float input */
private fun bitmapToFloatNHWC(bitmap: Bitmap, inputBuffer: ByteBuffer, pixels: IntArray) {
  inputBuffer.rewind()
  bitmap.getPixels(pixels, 0, bitmap.width, 0, 0, bitmap.width, bitmap.height)
  for (p in pixels) {
    inputBuffer.putFloat(((p shr 16) and 0xFF) / 255f) // R
    inputBuffer.putFloat(((p shr 8) and 0xFF) / 255f)  // G
    inputBuffer.putFloat((p and 0xFF) / 255f)          // B
  }
  inputBuffer.rewind()
}

private fun allocateOutput(shape: IntArray): Any {
  return when {
    shape.size == 3 && shape[1] == 84 -> Array(1) { Array(84) { FloatArray(shape[2]) } } // [1][84][N]
    shape.size == 3 && shape[2] == 84 -> Array(1) { Array(shape[1]) { FloatArray(84) } } // [1][N][84]
    else -> Array(1) { Array(84) { FloatArray(8400) } }
  }
}

/** Convert TFLite output to [84][N] */
private fun to84xN(output: Any, shape: IntArray): Array<FloatArray>? {
  return when {
    shape.size == 3 && shape[1] == 84 -> {
      @Suppress("UNCHECKED_CAST")
      (output as Array<Array<FloatArray>>)[0] // [84][N]
    }
    shape.size == 3 && shape[2] == 84 -> {
      @Suppress("UNCHECKED_CAST")
      val outN84 = (output as Array<Array<FloatArray>>)[0] // [N][84]
      val n = outN84.size
      Array(84) { c -> FloatArray(n) { j -> outN84[j][c] } } // -> [84][N]
    }
    else -> null
  }
}

/** COCO80 labels */
private val coco80 = listOf(
  "person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light",
  "fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow",
  "elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee",
  "skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle",
  "wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange",
  "broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed",
  "dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven",
  "toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"
)