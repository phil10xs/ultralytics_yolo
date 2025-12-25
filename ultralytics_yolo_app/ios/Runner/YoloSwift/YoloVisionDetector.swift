//
//  YoloVisionDetector.swift
//  Runner
//
//  Created by Philip Igboba on 22/12/2025.

import Foundation
import Vision
import CoreML
import UIKit


struct YoloDetection: Identifiable {
    let id = UUID()
    let rectNormalized: CGRect   // 0..1 in view space (top-left origin)
    let label: String
    let confidence: Float
}

final class YoloVisionDetector {

    private let coco80: [String] = [
        "person","bicycle","car","motorcycle","airplane","bus","train","truck","boat","traffic light",
        "fire hydrant","stop sign","parking meter","bench","bird","cat","dog","horse","sheep","cow",
        "elephant","bear","zebra","giraffe","backpack","umbrella","handbag","tie","suitcase","frisbee",
        "skis","snowboard","sports ball","kite","baseball bat","baseball glove","skateboard","surfboard","tennis racket","bottle",
        "wine glass","cup","fork","knife","spoon","bowl","banana","apple","sandwich","orange",
        "broccoli","carrot","hot dog","pizza","donut","cake","chair","couch","potted plant","bed",
        "dining table","toilet","tv","laptop","mouse","remote","keyboard","cell phone","microwave","oven",
        "toaster","sink","refrigerator","book","clock","vase","scissors","teddy bear","hair drier","toothbrush"
    ]

    // You can temporarily drop this to 0.10 while debugging
    private let confidenceThreshold: Float
    private let iouThreshold: Float
    private let inputSize: Float = 640

    // Debug toggles
    private let debugLogs = true
    private var logEvery = 15
    private var frameCount = 0

    private var request: VNCoreMLRequest?
    private let handler = VNSequenceRequestHandler()

    init(confThreshold: Float = 0.25, iouThreshold: Float = 0.45) {
        self.confidenceThreshold = confThreshold
        self.iouThreshold = iouThreshold
        loadModel()
    }

    private func loadModel() {
        do {
            guard let url = Bundle.main.url(forResource: "yolo11n", withExtension: "mlmodelc") else {
                print("❌ Could not find yolo11n.mlmodelc in bundle. Check Copy Bundle Resources.")
                return
            }

            let mlModel = try MLModel(contentsOf: url, configuration: MLModelConfiguration())
            let vnModel = try VNCoreMLModel(for: mlModel)

            let req = VNCoreMLRequest(model: vnModel) { _, error in
                if let error = error {
                    print("❌ Vision request error:", error)
                }
            }
            req.imageCropAndScaleOption = .scaleFill
            self.request = req

            print(" CoreML model loaded (Vision)")
        } catch {
            print(" Failed to load CoreML model:", error)
        }
    }

    func perform(on pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> ([YoloDetection], Double) {
        guard let req = request else { return ([], 0) }

        let t0 = CACurrentMediaTime()
        do {
            try handler.perform([req], on: pixelBuffer, orientation: orientation)
        } catch {
            print(" handler.perform failed:", error)
            return ([], 0)
        }
        let inferMs = (CACurrentMediaTime() - t0) * 1000.0

        guard let results = req.results, !results.isEmpty else {
            if debugLogs { print("⚠️ No Vision results") }
            return ([], inferMs)
        }

        // Best case (not your current model)
        if let objects = results as? [VNRecognizedObjectObservation] {
            let dets = objects.compactMap { obs -> YoloDetection? in
                guard let top = obs.labels.first else { return nil }
                let conf = Float(top.confidence)
                guard conf >= confidenceThreshold else { return nil }

                let bb = obs.boundingBox
                let rectTopLeft = CGRect(
                    x: bb.origin.x,
                    y: 1.0 - bb.origin.y - bb.size.height,
                    width: bb.size.width,
                    height: bb.size.height
                )
                return YoloDetection(rectNormalized: rectTopLeft, label: top.identifier, confidence: conf)
            }
            return (nms(dets: dets, thr: iouThreshold), inferMs)
        }

        // Your case: VNCoreMLFeatureValueObservation
        if let fv = results.first as? VNCoreMLFeatureValueObservation,
           let arr = fv.featureValue.multiArrayValue {

            frameCount += 1
            if debugLogs && frameCount % logEvery == 0 {
                print("🔎 MLMultiArray shape:", arr.shape.map { $0.intValue })
                print("🔎 MLMultiArray strides:", arr.strides.map { $0.intValue })
                print("🔎 MLMultiArray type:", arr.dataType.rawValue)
                logMultiArrayStats(arr, sampleCount: 5000)
            }

            let dets = decodeYoloMultiArray(arr)
            if debugLogs && frameCount % logEvery == 0 {
                print("decoded dets:", dets.count, "confThr:", confidenceThreshold)
                if let top = dets.max(by: { $0.confidence < $1.confidence }) {
                    print("🏆 top:", top.label, top.confidence, "rect:", top.rectNormalized)
                }
            }
            return (dets, inferMs)
        }

        if debugLogs {
            print("⚠️ Vision result type:", type(of: results.first!))
        }
        return ([], inferMs)
    }

    // MARK: - Decode

    private func decodeYoloMultiArray(_ a: MLMultiArray) -> [YoloDetection] {
        let shape = a.shape.map { $0.intValue }
        let strides = a.strides.map { $0.intValue }

        func v3(_ i0: Int, _ i1: Int, _ i2: Int) -> Float {
            let idx = i0 * strides[0] + i1 * strides[1] + i2 * strides[2]
            return a[idx].floatValue
        }
        func v2(_ i0: Int, _ i1: Int) -> Float {
            let idx = i0 * strides[0] + i1 * strides[1]
            return a[idx].floatValue
        }

        // Convert to [84][N]
        var out84N: [[Float]] = Array(repeating: Array(repeating: 0, count: 8400), count: 84)

        if shape.count == 3 && shape[1] == 84 {
            let n = shape[2]
            if n != 8400 && debugLogs { print("⚠️ N != 8400. N =", n) }
            for c in 0..<84 { for j in 0..<min(n, 8400) { out84N[c][j] = v3(0, c, j) } }
        } else if shape.count == 3 && shape[2] == 84 {
            let n = shape[1]
            if n != 8400 && debugLogs { print("⚠️ N != 8400. N =", n) }
            for j in 0..<min(n, 8400) { for c in 0..<84 { out84N[c][j] = v3(0, j, c) } }
        } else if shape.count == 2 && shape[0] == 84 {
            let n = shape[1]
            if n != 8400 && debugLogs { print("⚠️ N != 8400. N =", n) }
            for c in 0..<84 { for j in 0..<min(n, 8400) { out84N[c][j] = v2(c, j) } }
        } else {
            if debugLogs { print("❌ Unsupported output shape:", shape) }
            return []
        }

        return decode84xN(out84N)
    }

    /// Robust decoder:
    /// - Supports both “obj present” and “no-obj” exports
    /// - Auto-detects scale (0..1 vs 0..640)
    /// - Logs max scores so you can see why candidates drop to 0
    private func decode84xN(_ out: [[Float]]) -> [YoloDetection] {
        let n = out[0].count
        var candidates: [YoloDetection] = []
        candidates.reserveCapacity(64)

        var maxCls: Float = 0
        var maxScoreFinal: Float = 0

        for j in 0..<n {
            let cx = out[0][j]
            let cy = out[1][j]
            let w  = out[2][j]
            let h  = out[3][j]

            // For [1,84,8400] => classes start at channel 4
            var bestCls = 0
            var bestScore: Float = 0
            for c in 4..<84 {
                let sc = out[c][j]
                if sc > bestScore { bestScore = sc; bestCls = c - 4 } // correct index
            }

            if bestScore > maxCls { maxCls = bestScore }

            // score is class score only (no objectness in 84ch layout)
            let score = bestScore
            if score > maxScoreFinal { maxScoreFinal = score }
            if score < confidenceThreshold { continue }

            // Scale detect: pixel-space vs normalized
            let scale: Float = (cx > 2 || cy > 2 || w > 2 || h > 2) ? inputSize : 1.0

            var left   = (cx - w/2) / scale
            var top    = (cy - h/2) / scale
            var right  = (cx + w/2) / scale
            var bottom = (cy + h/2) / scale

            left = clamp(left, 0, 1)
            top = clamp(top, 0, 1)
            right = clamp(right, 0, 1)
            bottom = clamp(bottom, 0, 1)

            let ww = max(0, right - left)
            let hh = max(0, bottom - top)
            if ww <= 0 || hh <= 0 { continue }

            let rect = CGRect(
                x: CGFloat(left),
                y: CGFloat(top),
                width: CGFloat(ww),
                height: CGFloat(hh)
            )

            let label = coco80.indices.contains(bestCls) ? coco80[bestCls] : "cls\(bestCls)"
            candidates.append(YoloDetection(rectNormalized: rect, label: label, confidence: score))
        }

        if debugLogs && frameCount % logEvery == 0 {
            print("📌 decode84xN FIXED: n=\(n) cand=\(candidates.count) maxCls=\(maxCls) maxScore=\(maxScoreFinal)")
        }

        return nms(dets: candidates, thr: iouThreshold).prefix(20).map { $0 }
    }
    // MARK: - NMS

    private func nms(dets: [YoloDetection], thr: Float) -> [YoloDetection] {
        let sorted = dets.sorted { $0.confidence > $1.confidence }
        var kept: [YoloDetection] = []
        var suppressed = Array(repeating: false, count: sorted.count)

        for i in 0..<sorted.count {
            if suppressed[i] { continue }
            kept.append(sorted[i])
            for j in (i+1)..<sorted.count {
                if suppressed[j] { continue }
                if iou(sorted[i].rectNormalized, sorted[j].rectNormalized) > thr {
                    suppressed[j] = true
                }
            }
        }
        return kept
    }

    private func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let ax2 = a.origin.x + a.size.width
        let ay2 = a.origin.y + a.size.height
        let bx2 = b.origin.x + b.size.width
        let by2 = b.origin.y + b.size.height

        let x1 = max(a.origin.x, b.origin.x)
        let y1 = max(a.origin.y, b.origin.y)
        let x2 = min(ax2, bx2)
        let y2 = min(ay2, by2)

        let interW = max(0, x2 - x1)
        let interH = max(0, y2 - y1)
        let inter = interW * interH

        let areaA = a.size.width * a.size.height
        let areaB = b.size.width * b.size.height
        let denom = areaA + areaB - inter
        if denom <= 0 { return 0 }
        return Float(inter / denom)
    }

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        return min(max(v, lo), hi)
    }

    // MARK: - Logs

    private func logMultiArrayStats(_ a: MLMultiArray, sampleCount: Int) {
        // Random-ish sampling across first N elements
        let total = a.count
        let n = min(sampleCount, total)
        if n <= 0 { return }

        var minV: Float = .greatestFiniteMagnitude
        var maxV: Float = -.greatestFiniteMagnitude
        var sum: Double = 0

        // Step through array to avoid reading the entire thing
        let step = max(1, total / n)
        var i = 0
        while i < total {
            let v = a[i].floatValue
            if v < minV { minV = v }
            if v > maxV { maxV = v }
            sum += Double(v)
            i += step
        }

        let approxMean = sum / Double(n)
        print("📊 multiArray approx stats: min=\(minV) max=\(maxV) mean≈\(approxMean)")
    }
}

