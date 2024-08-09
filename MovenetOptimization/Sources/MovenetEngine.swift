/* Copyright 2024 The FitsInc Authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 ==============================================================================*/

import AVFoundation
import UIKit
import TensorFlowLite

public final class MovenetEngine {

    public static let shared = MovenetEngine()

    public typealias DetectingResult = Result<Person, Error>

    private let queue = DispatchQueue(label: "serial_queue")
    private let isRunning = Atomic<Bool>(false)
    private var interpreter: Interpreter?
    private var inputTensor: Tensor?
    private var outputTensor: Tensor?

    public func initialize(
        threadCount: Int = 2,
        delegate: TFLDelegate = .auto,
        completion: @escaping (Bool) -> Void
    ) {
        queue.async { [weak self] in
            let moduleBundle = Bundle(for: MovenetEngine.self)
            guard let self = self,
                  let model = moduleBundle.path(forResource: "movenet_singlepose_thunder_3", ofType: "tflite") else {
                completion(false)
                return
            }

            var options = Interpreter.Options()
            options.threadCount = threadCount
            var delegates: [Delegate]?
            switch delegate {
            case .auto:
                if let coreMLDelegate = CoreMLDelegate() {
                    delegates = [coreMLDelegate]
                } else {
                    delegates = [MetalDelegate()]
                }
            case .gpu:
                delegates = [MetalDelegate()]
            case .npu:
                if let coreMLDelegate = CoreMLDelegate() {
                    delegates = [coreMLDelegate]
                } else {
                    delegates = nil
                }
            case .cpu:
                delegates = nil
            }

            do {
                let interpreter = try Interpreter(modelPath: model, options: options, delegates: delegates)
                self.interpreter = interpreter
                try interpreter.allocateTensors()
                self.inputTensor = try interpreter.input(at: 0)
                self.outputTensor = try interpreter.output(at: 0)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }

    public func processWithOpenCV(
        with sampleBuffer: CMSampleBuffer,
        completion: @escaping (Times?, DetectingResult) -> Void
    ) {
        guard !isRunning.value else {
            completion(nil, .failure(PoseEstimationError.modelBusy))
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                completion(nil, .failure(PoseEstimationError.notInitialized))
                return
            }

            self.isRunning.mutate({ $0 = true })
            defer { self.isRunning.mutate({ $0 = false })}

            var preprocessingTime: TimeInterval = 0
            var inferenceTime: TimeInterval = 0

            do {
                let preprocessingStartTime = Date()
                let imageData = try self.preprocessWithOpenCV(with: sampleBuffer)
                preprocessingTime = Date().timeIntervalSince(preprocessingStartTime)
                let inferenceStartTime = Date()
                try inference(data: imageData)
                inferenceTime = Date().timeIntervalSince(inferenceStartTime)
            } catch {
                completion(nil, .failure(error))
                return
            }

            let postprocessingStartTime = Date()
            guard let tensor = outputTensor,
                  let person = postprocess(modelOutput: tensor) else {
                completion(nil, .failure(PoseEstimationError.postProcessingFailed))
                return
            }
            let postprocessingTime = Date().timeIntervalSince(postprocessingStartTime)

            completion(
                Times(preprocessing: preprocessingTime, inference: inferenceTime, postprocessing: postprocessingTime),
                .success(person)
            )
        }
    }

    public func process(
        with sampleBuffer: CMSampleBuffer,
        completion: @escaping (Times?, DetectingResult) -> Void
    ) {
        guard !isRunning.value else {
            completion(nil, .failure(PoseEstimationError.modelBusy))
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                completion(nil, .failure(PoseEstimationError.notInitialized))
                return
            }

            self.isRunning.mutate({ $0 = true })
            defer { self.isRunning.mutate({ $0 = false })}

            var preprocessingTime: TimeInterval = 0
            var inferenceTime: TimeInterval = 0
            var postprocessingTime: TimeInterval = 0

            do {
                let preprocessingStartTime = Date()
                guard let imageData = self.preprocess(with: sampleBuffer) else {
                    throw PoseEstimationError.preprocessingFailed
                }
                preprocessingTime = Date().timeIntervalSince(preprocessingStartTime)
                let inferenceStartTime = Date()
                try self.inference(data: imageData)
                inferenceTime = Date().timeIntervalSince(inferenceStartTime)
            } catch {
                completion(nil, .failure(error))
                return
            }

            let postprocessingStartTime = Date()
            guard let tensor = self.outputTensor,
                  let person = self.postprocess(modelOutput: tensor) else {
                completion(nil, .failure(PoseEstimationError.postProcessingFailed))
                return
            }
            postprocessingTime = Date().timeIntervalSince(postprocessingStartTime)

            completion(
                Times(preprocessing: preprocessingTime, inference: inferenceTime, postprocessing: postprocessingTime),
                .success(person)
            )
        }
    }
}

extension MovenetEngine {

    func preprocessWithOpenCV(with sampleBuffer: CMSampleBuffer) throws -> Data {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            throw PoseEstimationError.preprocessingFailed
        }

        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }

        let ptr = CVPixelBufferGetBaseAddressOfPlane(buffer, 0)
        let width = Int32(CVPixelBufferGetWidthOfPlane(buffer, 0))
        let height = Int32(CVPixelBufferGetHeightOfPlane(buffer, 0))
        let bytesPerRow = Int32(CVPixelBufferGetBytesPerRowOfPlane(buffer, 0))
        let result = Preprocessor.preprocess(
            ptr,
            width: width,
            height: height,
            bytesPerRow: bytesPerRow
        )
        return result
    }

    func preprocess(with sampleBuffer: CMSampleBuffer) -> Data? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        assert(
            sourcePixelFormat == kCVPixelFormatType_32BGRA
            || sourcePixelFormat == kCVPixelFormatType_32ARGB)

        guard let tensor = inputTensor else { return nil }
        let dimensions = tensor.shape.dimensions
        let inputWidth = dimensions[1]
        let inputHeight = dimensions[2]
        let modelSize = CGSize(width: inputWidth, height: inputHeight)

        let originalWidth = CVPixelBufferGetWidth(pixelBuffer)
        let originalHeight = CVPixelBufferGetHeight(pixelBuffer)

        var paddedPixelBuffer: CVPixelBuffer? = nil
        if originalWidth != originalHeight {
            let longerSide = max(originalWidth, originalHeight)
            let paddingWidth = (longerSide - originalWidth) / 2
            let paddingHeight = (longerSide - originalHeight) / 2

            paddedPixelBuffer = pixelBuffer.addPadding(paddingWidth: paddingWidth, paddingHeight: paddingHeight)
        } else {
            paddedPixelBuffer = pixelBuffer
        }

        guard let paddedBuffer = paddedPixelBuffer, let resizedPixelBuffer = paddedBuffer.resized(to: modelSize) else { return nil }
        return resizedPixelBuffer.rgbData(isModelQuantized: false, imageMean: 0.0, imageStd: 1.0)
    }

    private func inference(data: Data) throws {
        guard let interpreter = self.interpreter else {
            throw PoseEstimationError.notInitialized
        }

        try interpreter.copy(data, toInputAt: 0)
        try interpreter.invoke()
        outputTensor = try interpreter.output(at: 0)
    }

    private func postprocess(modelOutput: Tensor) -> Person? {
        let preprocessingStartTime: Date
        let inferenceStartTime: Date
        let postprocessingStartTime: Date

        let preprocessingTime: TimeInterval
        let inferenceTime: TimeInterval
        let postprocessingTime: TimeInterval

        preprocessingStartTime = Date()
        preprocessingTime = Date().timeIntervalSince(preprocessingStartTime)
        inferenceStartTime = Date()
        let output = modelOutput.data.toArray(type: Float32.self)
        let dimensions = modelOutput.shape.dimensions
        let numKeyPoints = dimensions[2]
        var totalScoreSum: Float32 = 0
        var keyPoints: [KeyPoint] = []
        var isAllMatched = true
        for idx in 0..<numKeyPoints {
            let x = CGFloat(output[idx * 3 + 1])
            let y = CGFloat(output[idx * 3 + 0])
            let score = output[idx * 3 + 2]
            totalScoreSum += score
            let keyPoint = KeyPoint(
                bodyPart: BodyPart.allCases[idx], coordinate: CGPoint(x: x, y: y), score: score)
            if score < 0.2 { isAllMatched = false }
            keyPoints.append(keyPoint)
        }

        // Calculates total confidence score of each key position.
        let totalScore = totalScoreSum / Float32(numKeyPoints)

        // Make `Person` from `keypoints'. Each point is adjusted to the coordinate of the input image.
        return Person(keyPoints: keyPoints, score: totalScore, isAllMatched: isAllMatched)
    }
}
