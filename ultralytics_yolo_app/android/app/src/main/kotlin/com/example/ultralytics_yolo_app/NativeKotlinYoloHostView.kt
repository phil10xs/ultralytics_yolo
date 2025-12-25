package com.example.ultralytics_yolo_app

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import org.tensorflow.lite.Interpreter
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicLong

private const val TAG = "NativeKotlinYoloHostView"

class NativeKotlinYoloHostView(ctx: Context) : FrameLayout(ctx) {

  private val previewView: PreviewView = PreviewView(ctx).apply {
    implementationMode = PreviewView.ImplementationMode.COMPATIBLE
  }

  private val overlayView = OverlayView(ctx)

  private var cameraProvider: ProcessCameraProvider? = null
  private var interpreter: Interpreter? = null
  private var cameraExecutor: ExecutorService? = null

  @Volatile private var started = false
  private val runId = AtomicLong(0L)

  init {
    addView(previewView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))
    addView(overlayView, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT))

    overlayView.bringToFront()
    overlayView.setWillNotDraw(false)
    overlayView.isClickable = false
    overlayView.isFocusable = false
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    Log.d(TAG, "onDetachedFromWindow() -> stop()")
    stop()
  }

  fun start(
    lifecycleOwner: LifecycleOwner,
    modelAsset: String,
    inputSize: Int,
    confThreshold: Float,
    iouThreshold: Float
  ) {
    if (started) {
      Log.d(TAG, "start() ignored: already started")
      return
    }
    started = true

    val myRunId = runId.incrementAndGet()
    Log.d(TAG, "start() model=$modelAsset inputSize=$inputSize conf=$confThreshold iou=$iouThreshold runId=$myRunId")

    if (cameraExecutor == null) cameraExecutor = Executors.newSingleThreadExecutor()

    overlayView.bringToFront()
    overlayView.setWillNotDraw(false)
    overlayView.invalidate()

    if (interpreter == null) {
      try {
        interpreter = TFLiteUtil.loadModelFromFlutterAssets(context, modelAsset)
        Log.d(TAG, "TFLite interpreter created")
      } catch (t: Throwable) {
        Log.e(TAG, "Failed to load TFLite model: $modelAsset", t)
        stop()
        return
      }
    }

    val providerFuture = ProcessCameraProvider.getInstance(context)
    providerFuture.addListener(
      {
        val provider: ProcessCameraProvider = try {
          providerFuture.get()
        } catch (t: Throwable) {
          Log.e(TAG, "Failed to get ProcessCameraProvider", t)
          stop()
          return@addListener
        }

        if (!started || runId.get() != myRunId) return@addListener

        cameraProvider = provider

        val preview = Preview.Builder()
          .build()
          .also { it.setSurfaceProvider(previewView.surfaceProvider) }

        val analysis = ImageAnalysis.Builder()
          .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
          .setImageQueueDepth(1)
          .build()

        val tflite = interpreter
        val exec = cameraExecutor
        if (tflite == null || exec == null) {
          Log.e(TAG, "start() aborted: interpreter/executor is null")
          stop()
          return@addListener
        }

        overlayView.setDetections(emptyList(), 0.0, 0.0)
        overlayView.bringToFront()

        analysis.setAnalyzer(
          exec,
          YoloAnalyzer(
            interpreter = tflite,
            inputSize = inputSize,
            confThreshold = confThreshold,
            iouThreshold = iouThreshold
          ) { dets, fps, inferMs ->
            overlayView.post {
              if (!started || runId.get() != myRunId) return@post
              overlayView.setDetections(dets, fps, inferMs)
              overlayView.bringToFront()
            }
          }
        )

        try {
          provider.unbindAll()
          provider.bindToLifecycle(
            lifecycleOwner,
            CameraSelector.DEFAULT_BACK_CAMERA,
            preview,
            analysis
          )
          Log.d(TAG, "CameraX bindToLifecycle OK")
        } catch (t: Throwable) {
          Log.e(TAG, "bindToLifecycle FAILED", t)
          stop()
        }
      },
      ContextCompat.getMainExecutor(context)
    )
  }

  fun stop() {
    if (!started) return
    started = false

    val newId = runId.incrementAndGet()
    Log.d(TAG, "stop() runId -> $newId")

    runCatching { cameraProvider?.unbindAll() }
      .onFailure { Log.e(TAG, "unbindAll failed", it) }
    cameraProvider = null

    runCatching { interpreter?.close() }
      .onFailure { Log.e(TAG, "interpreter close failed", it) }
    interpreter = null

    runCatching { cameraExecutor?.shutdown() }
      .onFailure { Log.e(TAG, "executor shutdown failed", it) }
    cameraExecutor = null
  }

  data class Detection(val rect: RectF, val label: String, val score: Float)

  private class OverlayView(ctx: Context) : View(ctx) {

    private val boxPaint = Paint().apply {
      style = Paint.Style.STROKE
      strokeWidth = dp(3f)
      isAntiAlias = true
      color = Color.rgb(0, 255, 180)
    }

    private val labelBgPaint = Paint().apply {
      style = Paint.Style.FILL
      color = Color.argb(200, 0, 0, 0)
      isAntiAlias = true
    }

    private val labelTextPaint = Paint().apply {
      style = Paint.Style.FILL
      textSize = sp(14f)
      color = Color.WHITE
      isAntiAlias = true
      setShadowLayer(4f, 0f, 0f, Color.BLACK)
    }

    private val chipBgPaint = Paint().apply {
      style = Paint.Style.FILL
      color = Color.argb(220, 20, 20, 20)
      isAntiAlias = true
    }

    private val chipTextPaint = Paint().apply {
      style = Paint.Style.FILL
      textSize = sp(14f)
      color = Color.WHITE
      isAntiAlias = true
      setShadowLayer(2f, 0f, 0f, Color.BLACK)
    }

    @Volatile private var dets: List<Detection> = emptyList()
    @Volatile private var fps: Double = 0.0
    @Volatile private var inferMs: Double = 0.0

    fun setDetections(newDets: List<Detection>, newFps: Double, newInferMs: Double) {
      dets = newDets
      fps = newFps
      inferMs = newInferMs
      postInvalidateOnAnimation()
    }

    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas)

      val vw = width.toFloat().coerceAtLeast(1f)
      val vh = height.toFloat().coerceAtLeast(1f)

      val right = vw - dp(12f)
      drawChip(canvas, "FPS ${"%.1f".format(fps)}", right, dp(12f))
      drawChip(canvas, "${"%.1f".format(inferMs)} ms", right, dp(60f))

      for (d in dets) {
        val r = RectF(
          d.rect.left * vw,
          d.rect.top * vh,
          d.rect.right * vw,
          d.rect.bottom * vh
        )

        canvas.drawRect(r, boxPaint)

        val label = "${d.label} ${"%.1f".format(d.score * 100)}%"
        val textW = labelTextPaint.measureText(label)
        val textH = labelTextPaint.textSize

        val bg = RectF(
          r.left,
          (r.top - textH - dp(8f)).coerceAtLeast(dp(2f)),
          (r.left + textW + dp(12f)).coerceAtMost(vw - dp(2f)),
          r.top.coerceAtLeast(dp(2f)) + dp(2f)
        )

        canvas.drawRoundRect(bg, dp(6f), dp(6f), labelBgPaint)
        canvas.drawText(label, bg.left + dp(6f), bg.bottom - dp(6f), labelTextPaint)
      }
    }

    private fun drawChip(canvas: Canvas, text: String, right: Float, top: Float) {
      val padX = dp(12f)
      val chipH = dp(40f)
      val textW = chipTextPaint.measureText(text)

      val rect = RectF(right - textW - padX * 2, top, right, top + chipH)
      canvas.drawRoundRect(rect, dp(12f), dp(12f), chipBgPaint)

      val baseline = rect.top + chipH / 2f + chipTextPaint.textSize / 2f - dp(2f)
      canvas.drawText(text, rect.left + padX, baseline, chipTextPaint)
    }

    private fun dp(v: Float) = v * resources.displayMetrics.density
    private fun sp(v: Float) = v * resources.displayMetrics.scaledDensity
  }
}
