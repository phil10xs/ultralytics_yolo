//
//  YoloPostProcessing.swift
//  Runner
//
//  Created by Philip Igboba on 25/12/2025.
//

import Foundation
import CoreGraphics

struct YoloPostProcessor {

    struct Detection: Equatable {
        let rect: CGRect        // normalized 0..1, top-left origin not required here (that’s UI-layer)
        let cls: Int
        let score: Float
        let label: String
    }

    private let labels: [String]
    private let inputSize: Int
    private let conf: Float
    private let iouThr: Float

    init(labels: [String],
         inputSize: Int = 640,
         conf: Float = 0.25,
         iou: Float = 0.45) {
        self.labels = labels
        self.inputSize = inputSize
        self.conf = conf
        self.iouThr = iou
    }

    /// out is [84][N] (channel-major), where:
    /// 0=cx,1=cy,2=w,3=h,4=obj, 5..83 = class scores
    func decode84xN(_ out: [[Float]]) -> [Detection] {
        // Expect either:
        // A) channel-major: [84][N]
        // B) row-major:     [N][84]  (needs transpose)
        guard !out.isEmpty else { return [] }

        let s = Float(max(inputSize, 1))

        // Determine layout
        let rows = out.count
        let cols = out[0].count

        // We need channel-major data: ch[c][j]
        let ch: [[Float]]

        if rows == 84 {
            // Already [84][N]
            ch = out
        } else if cols == 84 {
            // It's [N][84] -> transpose to [84][N]
            let n = rows
            var t = Array(repeating: Array(repeating: Float(0), count: n), count: 84)
            for j in 0..<n {
                let row = out[j]
                if row.count < 84 { continue }
                for c in 0..<84 { t[c][j] = row[c] }
            }
            ch = t
        } else {
            // Unknown shape
            return []
        }

        guard ch.count == 84, let n = ch.first?.count, n > 0 else { return [] }
        // Need at least bbox(0..3) + obj(4) + classes(5..83)
        // If not, return safely
        if ch.count < 85 && ch.count != 84 { return [] }

        var dets: [Detection] = []
        dets.reserveCapacity(min(n, 50))

        for j in 0..<n {
            let cx = ch[0][j]
            let cy = ch[1][j]
            let w  = ch[2][j]
            let h  = ch[3][j]
            let obj = ch[4][j]

            var bestCls = 0
            var bestClsScore: Float = 0

            // Safe bounds: channels 5..83 exist only if count == 84
            // (84 channels => 5..83 is valid)
            if ch.count >= 84 {
                for c in 0..<80 {
                    let idx = 5 + c
                    if idx >= ch.count { break }
                    let sc = ch[idx][j]
                    if sc > bestClsScore { bestClsScore = sc; bestCls = c }
                }
            } else {
                continue
            }

            let score = obj * bestClsScore
            if score < conf { continue }

            let leftPx = cx - w / 2
            let topPx  = cy - h / 2
            let rightPx = leftPx + w
            let bottomPx = topPx + h

            let x1 = max(0, min(1, leftPx / s))
            let y1 = max(0, min(1, topPx / s))
            let x2 = max(0, min(1, rightPx / s))
            let y2 = max(0, min(1, bottomPx / s))

            let rect = CGRect(
                x: CGFloat(x1),
                y: CGFloat(y1),
                width: CGFloat(max(0, x2 - x1)),
                height: CGFloat(max(0, y2 - y1))
            )
            if rect.width <= 0 || rect.height <= 0 { continue }

            let label = (bestCls < labels.count) ? labels[bestCls] : "cls\(bestCls)"
            dets.append(Detection(rect: rect, cls: bestCls, score: score, label: label))
        }

        return nms(dets, thr: iouThr)
    }

    /// NMS (per-class, YOLO-like)
    func nms(_ dets: [Detection], thr: Float) -> [Detection] {
        guard !dets.isEmpty else { return [] }

        var byClass: [Int: [Detection]] = [:]
        for d in dets { byClass[d.cls, default: []].append(d) }

        var keptAll: [Detection] = []
        keptAll.reserveCapacity(dets.count)

        for (_, list) in byClass {
            var sorted = list.sorted { $0.score > $1.score }
            var kept: [Detection] = []

            while !sorted.isEmpty {
                let top = sorted.removeFirst()
                kept.append(top)
                sorted.removeAll { cand in
                    iou(top.rect, cand.rect) > thr
                }
            }
            keptAll.append(contentsOf: kept)
        }

        keptAll.sort { $0.score > $1.score }
        return keptAll
    }

    func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let ax1 = a.minX, ay1 = a.minY, ax2 = a.maxX, ay2 = a.maxY
        let bx1 = b.minX, by1 = b.minY, bx2 = b.maxX, by2 = b.maxY

        let ix1 = max(ax1, bx1)
        let iy1 = max(ay1, by1)
        let ix2 = min(ax2, bx2)
        let iy2 = min(ay2, by2)

        let iw = max(0, ix2 - ix1)
        let ih = max(0, iy2 - iy1)
        let inter = iw * ih

        let areaA = max(0, ax2 - ax1) * max(0, ay2 - ay1)
        let areaB = max(0, bx2 - bx1) * max(0, by2 - by1)
        let denom = areaA + areaB - inter

        if denom <= 0 { return 0 }
        return Float(inter / denom)
    }
}
