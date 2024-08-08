//
//  CameraResoulution.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/6/24.
//

import AVFoundation
import CoreGraphics

public enum CameraResolution {

    case vga640x480
    case hd1280x720
    case hd1920x1080

    public var size: CGSize {
        switch self {
        case .vga640x480:
            return CGSize(width: 480, height: 640)
        case .hd1280x720:
            return CGSize(width: 720, height: 1280)
        case .hd1920x1080:
            return CGSize(width: 1080, height: 1920)
        }
    }

    public var preset: AVCaptureSession.Preset {
        switch self {
        case .vga640x480:
            return .vga640x480
        case .hd1280x720:
            return .hd1280x720
        case .hd1920x1080:
            return .hd1920x1080
        }
    }
}
