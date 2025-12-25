package com.example.ultralytics_yolo_app

import android.util.Log
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private const val TAG_POST = "YoloPost"

class YoloPostProcessor(
    private val labels: List<String>
) {
    enum class ScoreMode { AUTO, NO_OBJ, OBJ_TIMES_CLS }

    //Pure Kotlin rect so JVM tests work */
    data class RectN(val left: Float, val top: Float, val right: Float, val bottom: Float) {
        val width: Float get() = (right - left).coerceAtLeast(0f)
        val height: Float get() = (bottom - top).coerceAtLeast(0f)
        val centerX: Float get() = left + width / 2f
        val centerY: Float get() = top + height / 2f
    }

    data class Detection(
        val rect: RectN,   // normalized 0..1
        val cls: Int,
        val score: Float,
        val label: String
    )

    // Backwards-compatible: keeps your current callers working.
    fun decode84xN(
        out: Array<FloatArray>,
        conf: Float,
        iou: Float,
        inputSize: Int
    ): List<Detection> = decode84xN(out, conf, iou, inputSize, ScoreMode.AUTO)

    fun decode84xN(
        out: Array<FloatArray>, // [84][N]
        conf: Float,
        iou: Float,
        inputSize: Int,
        mode: ScoreMode
    ): List<Detection> {
        if (out.isEmpty() || out[0].isEmpty()) return emptyList()
        if (out.size < 84) return emptyList()

        val n = out[0].size
        for (c in 0 until 84) {
            if (out[c].size != n) return emptyList()
        }

        val s = inputSize.toFloat().coerceAtLeast(1f)

        // ---- detect coord space (norm vs px) ----
        var coordMax = 0f
        val sampleN = min(n, 200)
        for (k in 0..3) for (j in 0 until sampleN) coordMax = max(coordMax, abs(out[k][j]))
        val coordsAreNormalized = coordMax <= 1.5f

        // ---- detect scoring mode (unless forced) ----
        val useObj: Boolean = when (mode) {
            ScoreMode.NO_OBJ -> false
            ScoreMode.OBJ_TIMES_CLS -> true
            ScoreMode.AUTO -> {
                var maxScoreNoObj = 0f
                var maxScoreObj = 0f
                for (j in 0 until n) {
                    // no-obj: classes start at 4
                    var bestNoObj = 0f
                    for (c in 4 until 84) bestNoObj = max(bestNoObj, out[c][j])
                    maxScoreNoObj = max(maxScoreNoObj, bestNoObj)

                    // obj*cls: obj at 4, classes at 5..83
                    val obj = out[4][j]
                    var bestCls = 0f
                    for (c in 5 until 84) bestCls = max(bestCls, out[c][j])
                    maxScoreObj = max(maxScoreObj, obj * bestCls)
                }
                maxScoreObj > (maxScoreNoObj * 1.2f)
            }
        }

        val modeUsed = if (useObj) "obj*cls" else "no-obj"

        val candidates = ArrayList<Detection>(64)
        var maxScoreSeen = 0f

        for (j in 0 until n) {
            val cx = out[0][j]
            val cy = out[1][j]
            val w = out[2][j]
            val h = out[3][j]

            val score: Float
            val clsId: Int

            if (!useObj) {
                var best = 0f
                var bestCls = 0
                for (c in 4 until 84) {
                    val sc = out[c][j]
                    if (sc > best) { best = sc; bestCls = c - 4 }
                }
                score = best
                clsId = bestCls
            } else {
                val obj = out[4][j]
                var best = 0f
                var bestCls = 0
                for (c in 5 until 84) {
                    val sc = out[c][j]
                    if (sc > best) { best = sc; bestCls = c - 5 }
                }
                score = obj * best
                clsId = bestCls
            }

            maxScoreSeen = max(maxScoreSeen, score)
            if (score < conf) continue

            val left = cx - w / 2f
            val top = cy - h / 2f
            val right = left + w
            val bottom = top + h

            val rectN = if (coordsAreNormalized) {
                RectN(
                    left.coerceIn(0f, 1f),
                    top.coerceIn(0f, 1f),
                    right.coerceIn(0f, 1f),
                    bottom.coerceIn(0f, 1f)
                )
            } else {
                RectN(
                    (left / s).coerceIn(0f, 1f),
                    (top / s).coerceIn(0f, 1f),
                    (right / s).coerceIn(0f, 1f),
                    (bottom / s).coerceIn(0f, 1f)
                )
            }

            val label = labels.getOrNull(clsId) ?: "cls$clsId"
            candidates.add(Detection(rectN, clsId, score, label))
        }

        Log.d(
            TAG_POST,
            "decode84xN: n=$n coordsMax=$coordMax coords=${if (coordsAreNormalized) "norm" else "px"} " +
                    "mode=$modeUsed cand=${candidates.size} maxScore=$maxScoreSeen conf=$conf"
        )

        return nms(candidates, iou).take(20)
    }

    fun nms(dets: List<Detection>, thr: Float): List<Detection> {
        val sorted = dets.sortedByDescending { it.score }.toMutableList()
        val kept = mutableListOf<Detection>()
        while (sorted.isNotEmpty()) {
            val top = sorted.removeAt(0)
            kept.add(top)
            val it = sorted.iterator()
            while (it.hasNext()) {
                val d = it.next()
                if (iou(top.rect, d.rect) > thr) it.remove()
            }
        }
        return kept
    }

    fun iou(a: RectN, b: RectN): Float {
        val x1 = max(a.left, b.left)
        val y1 = max(a.top, b.top)
        val x2 = min(a.right, b.right)
        val y2 = min(a.bottom, b.bottom)

        val inter = max(0f, x2 - x1) * max(0f, y2 - y1)
        val areaA = a.width * a.height
        val areaB = b.width * b.height
        val denom = areaA + areaB - inter
        return if (denom <= 0f) 0f else inter / denom
    }
}