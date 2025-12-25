//
//  YoloPlatformView.swift.swift
//  Runner
//
//  Created by Philip Igboba on 25/12/2025.
//

import Foundation
import Flutter
import UIKit
import SwiftUI

final class YoloPlatformView: NSObject, FlutterPlatformView {

    private let container: UIView
    private let hosting: UIHostingController<YoloSwiftUIView>
    private let vm: YoloCameraViewModel

    init(frame: CGRect,
         viewIdentifier viewId: Int64,
         arguments args: Any?,
         binaryMessenger messenger: FlutterBinaryMessenger) {

        self.vm = YoloCameraViewModel()
        self.hosting = UIHostingController(rootView: YoloSwiftUIView(vm: vm))
        self.container = UIView(frame: frame)

        super.init()

        hosting.view.backgroundColor = .black
        hosting.view.frame = container.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(hosting.view)
    }

    func view() -> UIView {
        container
    }

    deinit {
        vm.stop()
    }
}
