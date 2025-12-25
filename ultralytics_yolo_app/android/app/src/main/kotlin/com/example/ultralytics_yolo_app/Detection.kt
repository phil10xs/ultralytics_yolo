package com.example.ultralytics_yolo_app

import android.graphics.RectF

data class Detection(
  val rect: RectF,   // normalized 0..1
  val label: String,
  val score: Float
)
