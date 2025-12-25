//
//  CameraService.swift
//  Runner
//
//  Created by Philip Igboba on 25/12/2025.
//


import Foundation
import AVFoundation
import UIKit

final class CameraService: NSObject {

    let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private let sessionQueue = DispatchQueue(label: "cam.session")
    private let videoQueue = DispatchQueue(label: "cam.video")

    var onFrame: ((CVPixelBuffer) -> Void)?

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.requestPermissionIfNeeded { granted in
                if !granted {
                    print("❌ Camera permission denied")
                    return
                }
                self.configureIfNeeded()
                if !self.session.isRunning {
                    self.session.startRunning()
                    print(" Session started")
                }
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.detachDelegate()
        }
    }

    private func requestPermissionIfNeeded(_ completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in completion(ok) }
        default:
            completion(false)
        }
    }

    private var configured = false
    private func configureIfNeeded() {
        guard !configured else { return }
        configured = true

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            print("❌ Camera input failed")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let out = AVCaptureVideoDataOutput()
        out.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        out.alwaysDiscardsLateVideoFrames = true
        out.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(out) else {
            print("❌ Cannot add output")
            session.commitConfiguration()
            return
        }
        session.addOutput(out)
        self.videoOutput = out

        if let conn = out.connection(with: .video) {
            conn.videoOrientation = .portrait
        }

        session.commitConfiguration()
        print(" Camera configured")
    }

    private func detachDelegate() {
        // break callback chain safely
        videoQueue.async { [weak self] in
            self?.onFrame = nil
            self?.videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        }
    }
}

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let px = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(px)
    }
}
