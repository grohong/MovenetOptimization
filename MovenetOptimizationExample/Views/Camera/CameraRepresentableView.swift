//
//  CameraViewRepresentable.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/6/24.
//

import SwiftUI
import AVFoundation

struct CameraViewRepresentable: UIViewRepresentable {

    typealias UIViewType = CameraView
    var isUseOpenCVPreprocessor: Bool
    var updateTotalTime: ((String) -> Void)?

    class Coordinator: NSObject {

        var parent: CameraViewRepresentable

        init(_ parent: CameraViewRepresentable) {
            self.parent = parent
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CameraView {
        let cameraView = CameraView(
            isUseOpenCVPreprocessor: isUseOpenCVPreprocessor,
            updateTotalTime: updateTotalTime
        )
        cameraView.initialize()
        return cameraView
    }

    func updateUIView(_ uiView: CameraView, context: Context) { }

    func dismantleUIView(_ uiView: CameraView, coordinator: Coordinator) {
        uiView.deinitialize()
    }
}
