//
//  CameraView.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/6/24.
//

import AVFoundation
import UIKit
import MovenetOptimization

public final class CameraView: UIView {

    private var captureSession: AVCaptureSession?
    private let captureQueue = DispatchQueue(label: "output.queue")
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var videoOutput: AVCaptureVideoDataOutput?

    private let isUseOpenCVPreprocessor: Bool
    private let drawingView = DrawingView()
    private var frameCount = 0
    private var startTime: TimeInterval?

    private var updateTotalTime: ((String) -> Void)?

    init(
        isUseOpenCVPreprocessor: Bool,
        updateTotalTime: ((String) -> Void)?
    ) {
        self.isUseOpenCVPreprocessor = isUseOpenCVPreprocessor
        super.init(frame: .zero)
        addSubview(drawingView)
        drawingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            drawingView.topAnchor.constraint(equalTo: topAnchor),
            drawingView.bottomAnchor.constraint(equalTo: bottomAnchor),
            drawingView.leftAnchor.constraint(equalTo: leftAnchor),
            drawingView.rightAnchor.constraint(equalTo: rightAnchor),
        ])
        drawingView.backgroundColor = .clear
        self.updateTotalTime = updateTotalTime
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayoutIfNeeded()
    }

    deinit {
        deinitialize()
    }
}

extension CameraView {

    public override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    public var isInitialized: Bool {
        (captureSession?.isRunning == true)
    }

    @discardableResult
    public func initialize(
        position: AVCaptureDevice.Position = .back,
        resolution: CameraResolution = .vga640x480
    ) -> Bool {
        guard captureSession == nil else { return true }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let newSession = AVCaptureSession()
            newSession.beginConfiguration()
            newSession.sessionPreset = resolution.preset

            // Add Video Input
            let wideAngleCam = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            )
            guard let camDevice = wideAngleCam,
                  let videoDeviceInput = try? AVCaptureDeviceInput(device: camDevice),
                  newSession.canAddInput(videoDeviceInput) else { return }
            newSession.addInput(videoDeviceInput)

            // Add Audio Input
            let audio = AVCaptureDevice.default(for: .audio)
            guard let audioDevice = audio,
                  let audioDeviceInput = try? AVCaptureDeviceInput(device: audioDevice),
                  newSession.canAddInput(audioDeviceInput) else { return }
            newSession.addInput(audioDeviceInput)

            // Add Camera Output
            let camOutput = AVCaptureVideoDataOutput()
            camOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)
            ]

            camOutput.alwaysDiscardsLateVideoFrames = true
            camOutput.setSampleBufferDelegate(self, queue: self.captureQueue)
            guard newSession.canAddOutput(camOutput) else { return }
            newSession.addOutput(camOutput)

            // Add Movie Output
            let movOutput = AVCaptureMovieFileOutput()
            guard newSession.canAddOutput(movOutput) else { return }
            newSession.addOutput(movOutput)

            // Video Mirroring
            guard let camConnection = camOutput.connection(with: .video),
                  camConnection.isVideoOrientationSupported else { return }

            if camConnection.isVideoMirroringSupported, position == .front {
                camConnection.isVideoMirrored = true
            }

            camConnection.videoOrientation = .portrait

            // Movie Mirroring
            guard let movConnection = movOutput.connection(with: .video),
                  movConnection.isVideoOrientationSupported else { return }

            if movConnection.isVideoMirroringSupported, position == .front {
                movConnection.isVideoMirrored = true
            }

            movConnection.videoOrientation = .portrait

            newSession.commitConfiguration()
            DispatchQueue.main.async {
                self.setupPreviewLayer(session: newSession)
                self.captureSession = newSession
                self.videoOutput = camOutput
            }
            newSession.startRunning()
        }

        return true
    }

    private func setupPreviewLayer(session: AVCaptureSession) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = self.bounds
        self.layer.insertSublayer(previewLayer, at: 0)
        self.videoPreviewLayer = previewLayer
    }

    public func updateLayoutIfNeeded() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoPreviewLayer?.frame = bounds
        CATransaction.commit()
    }

    public func deinitialize() {
        guard captureSession != nil else { return }

        NotificationCenter.default.removeObserver(self)
        if isInitialized == true {
            captureSession?.stopRunning()
        }

        videoPreviewLayer?.session = nil
        layer.sublayers?.removeAll()
        videoOutput = nil
        captureSession = nil
    }
}

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureFileOutputRecordingDelegate {

    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let height = CGFloat(CVPixelBufferGetHeight(pixelBuffer))

        if isUseOpenCVPreprocessor {
            MovenetEngine.shared.processWithOpenCV(with: sampleBuffer) { times, result in
                switch result {
                case .success(let person):
                    DispatchQueue.main.async { [weak self] in
                        self?.drawingView.drawKeypoints(person.keyPoints, imageSize: CGSize(width: width, height: height))
                        guard let total = times?.total else { return }
                        self?.updateTotalTime?(String(format: "%.2fms", total * 1000))
                    }
                case .failure:
                    return
                }
            }
        } else {
            MovenetEngine.shared.process(with: sampleBuffer) { times, result in
                switch result {
                case .success(let person):
                    DispatchQueue.main.async { [weak self] in
                        self?.drawingView.drawKeypoints(person.keyPoints, imageSize: CGSize(width: width, height: height))
                        guard let total = times?.total else { return }
                        self?.updateTotalTime?(String(format: "%.2fms", total * 1000))
                    }
                case .failure:
                    return
                }
            }
        }
    }

    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: (any Error)?) { }
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) { }
}
