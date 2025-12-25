//
//  YoloCameraViewModel.swift
//  Runner
//
//  Created by Philip Igboba on 25/12/2025.
//

import Foundation
import Combine
import UIKit
import ImageIO

final class YoloCameraViewModel: NSObject, ObservableObject {

    // Published (UI)
    @Published var detections: [YoloDetection] = []
    @Published var fps: Double = 0
    @Published var inferMs: Double = 0

    // Services
    let camera = CameraService()
    let detector = YoloVisionDetector(confThreshold: 0.25, iouThreshold: 0.45)

    // FPS
    private var lastFrameTime: CFTimeInterval = 0

    // Throttle (keeps it stable)
    private var lastInferStart: CFTimeInterval = 0
    private let minInferInterval: CFTimeInterval = 1.0 / 20.0 // request up to ~20 fps

    override init() {
        super.init()
        hookCamera()
    }

    private func hookCamera() {
        camera.onFrame = { [weak self] px in
            self?.handleFrame(px)
        }
    }

    func start() {
        camera.start()
    }

    func stop() {
        camera.stop()
        DispatchQueue.main.async { [weak self] in
            self?.detections = []
            self?.fps = 0
            self?.inferMs = 0
        }
    }

    private func handleFrame(_ px: CVPixelBuffer) {
        let now = CACurrentMediaTime()

        // FPS every frame (smoothed)
        if lastFrameTime > 0 {
            let inst = 1.0 / (now - lastFrameTime)
            let next = (fps == 0) ? inst : fps * 0.9 + inst * 0.1
            DispatchQueue.main.async { [weak self] in self?.fps = next }
        }
        lastFrameTime = now

        // Throttle inference
        if now - lastInferStart < minInferInterval { return }
        lastInferStart = now

        // Vision orientation for portrait camera feed
        let orientation: CGImagePropertyOrientation = .right

        let (dets, ms) = detector.perform(on: px, orientation: orientation)

        DispatchQueue.main.async { [weak self] in
            self?.inferMs = ms
            self?.detections = dets
        }
    }
}
