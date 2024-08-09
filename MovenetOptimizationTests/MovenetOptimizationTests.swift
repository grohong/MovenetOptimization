//
//  MovenetOptimizationTests.swift
//  MovenetOptimizationTests
//
//  Created by Hong Seong Ho on 8/8/24.
//

import XCTest
import AVFoundation
@testable import MovenetOptimization

final class MovenetOptimizationTests: XCTestCase {

    var engine: MovenetEngine!
    var sampleBuffer: CMSampleBuffer!

    override func setUpWithError() throws {
        engine = MovenetEngine.shared
        let expectation = XCTestExpectation(description: "Initialize MovenetEngine")
        engine.initialize { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)

        sampleBuffer = createSampleBuffer()
    }

    override func tearDownWithError() throws {
        engine = nil
        sampleBuffer = nil
    }

    func testPreprocessWithOpenCV() throws {
        measure {
            do {
                let data = try engine.preprocessWithOpenCV(with: sampleBuffer)
                XCTAssertNotNil(data, "Preprocessed data should not be nil")
            } catch {
                XCTFail("Preprocess failed with error: \(error)")
            }
        }
    }

    func testPreprocessWithOrigin() throws {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            XCTFail("Failed to get CVPixelBuffer from CMSampleBuffer")
            return
        }

        measure {
            let data = engine.preprocess(pixelBuffer)
            XCTAssertNotNil(data, "Preprocessed data should not be nil")
        }
    }

}

private extension MovenetOptimizationTests {

    func createSampleBuffer() -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let width = 1280
        let height = 720
        let attributes = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess,
              let buffer = pixelBuffer else { return nil }

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )

        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMTime(value: CMTimeValue(0), timescale: CMTimeScale(600))
        timingInfo.duration = CMTime.invalid
        timingInfo.decodeTimeStamp = CMTime.invalid

        var sampleBuffer: CMSampleBuffer?
        let sampleBufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        if sampleBufferStatus == kCMBlockBufferNoErr {
            return sampleBuffer
        } else {
            return nil
        }
    }

    func createPixelBuffer() -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: 1280,
            kCVPixelBufferHeightKey: 720
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, 1280, 720, kCVPixelFormatType_32BGRA, attributes, &pixelBuffer)
        return pixelBuffer!
    }
}
