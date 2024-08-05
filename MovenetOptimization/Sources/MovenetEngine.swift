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

    public func process(with sampleBuffer: CMSampleBuffer,
                        completion: @escaping (DetectingResult) -> Void) {
        guard !isRunning.value else {
            completion(.failure(PoseEstimationError.modelBusy))
            return
        }

        queue.async { [weak self] in
            guard let self = self else {
                completion(.failure(PoseEstimationError.notInitialized))
                return
            }

            self.isRunning.mutate({ $0 = true })
            defer { self.isRunning.mutate({ $0 = false })}

            do {
                let imageData = try self.preprocess(with: sampleBuffer)
                try inference(data: imageData)
            } catch {
                completion(.failure(error))
                return
            }

            guard let tensor = outputTensor,
                  let person = postprocess(modelOutput: tensor) else {
                completion(.failure(PoseEstimationError.postProcessingFailed))
                return
            }

            completion(.success(person))
        }
    }
}

extension MovenetEngine {

    private func preprocess(with sampleBuffer: CMSampleBuffer) throws -> Data {
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

    private func inference(data: Data) throws {
        guard let interpreter = self.interpreter else {
            throw PoseEstimationError.notInitialized
        }

        try interpreter.copy(data, toInputAt: 0)
        try interpreter.invoke()
        outputTensor = try interpreter.output(at: 0)
    }

    private func postprocess(modelOutput: Tensor) -> Person? {
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
