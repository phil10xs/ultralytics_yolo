//
//  YoloSwiftUI.swift
//  Runner
//
//  Created by Philip Igboba on 25/12/2025.
//


import SwiftUI

struct YoloSwiftUIView: View {

    @ObservedObject private var vm: YoloCameraViewModel

    init(vm: YoloCameraViewModel) {
        self._vm = ObservedObject(wrappedValue: vm)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            CameraPreview(session: vm.camera.session)
                .edgesIgnoringSafeArea(.all)

            // Overlay detections
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    ForEach(vm.detections) { det in
                        let r = det.rectNormalized
                        let x = r.origin.x * geo.size.width
                        let y = r.origin.y * geo.size.height
                        let w = r.size.width * geo.size.width
                        let h = r.size.height * geo.size.height

                        // Box
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green, lineWidth: 2)
                            .frame(width: w, height: h)
                            .position(x: x + w/2, y: y + h/2)

                        // Label
                        Text("\(det.label) \(Int(det.confidence * 100))%")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .position(x: x + min(w/2, 90), y: max(14, y - 10))
                    }
                }
            }

            // Chips (top-right)
            VStack(alignment: .trailing, spacing: 10) {
                chip("FPS \(String(format: "%.1f", vm.fps))")
                chip("\(String(format: "%.1f", vm.inferMs)) ms")
            }
            .padding(.top, 16)
            .padding(.trailing, 12)
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.75))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}
