package com.example.ultralytics_yolo_app

import android.graphics.Bitmap
import android.graphics.ImageFormat
import androidx.camera.core.ImageProxy

object ImageConverters {

  fun imageProxyToBitmap(image: ImageProxy): Bitmap? {
    if (image.format != ImageFormat.YUV_420_888) return null

    val width = image.width
    val height = image.height

    val yPlane = image.planes[0]
    val uPlane = image.planes[1]
    val vPlane = image.planes[2]

    val yBuffer = yPlane.buffer
    val uBuffer = uPlane.buffer
    val vBuffer = vPlane.buffer

    val yRowStride = yPlane.rowStride
    val uvRowStride = uPlane.rowStride
    val uvPixelStride = uPlane.pixelStride

    val out = IntArray(width * height)

    var outIndex = 0
    for (row in 0 until height) {
      val yRowOffset = row * yRowStride
      val uvRowOffset = (row / 2) * uvRowStride

      for (col in 0 until width) {
        val yIndex = yRowOffset + col
        val uvIndex = uvRowOffset + (col / 2) * uvPixelStride

        val y = (yBuffer.getAt(yIndex).toInt() and 0xFF)
        val u = (uBuffer.getAt(uvIndex).toInt() and 0xFF) - 128
        val v = (vBuffer.getAt(uvIndex).toInt() and 0xFF) - 128

        var r = (y + 1.402f * v).toInt()
        var g = (y - 0.344f * u - 0.714f * v).toInt()
        var b = (y + 1.772f * u).toInt()

        r = r.coerceIn(0, 255)
        g = g.coerceIn(0, 255)
        b = b.coerceIn(0, 255)

        out[outIndex++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b
      }
    }

    return Bitmap.createBitmap(out, width, height, Bitmap.Config.ARGB_8888)
  }

  private fun java.nio.ByteBuffer.getAt(idx: Int): Byte {
    val oldPos = position()
    position(idx)
    val v = get()
    position(oldPos)
    return v
  }
}
