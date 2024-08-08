//
//  DrawingView.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/7/24.
//

import UIKit
import MovenetOptimization

public final class DrawingView: UIView {

    public func drawKeypoints(_ keypoints: [KeyPoint], imageSize: CGSize) {
        layer.sublayers?.removeAll()
        keypoints.forEach { keypoint in
            if keypoint.score >= 0.2 {
                let originPoint = keypoint.coordinate.changeScale(
                    to: imageSize,
                    parentScreenSize: CGSize(width: 1, height: 1))

                let scaledPoint = originPoint.changeScale(
                    to: frame.size,
                    parentScreenSize: imageSize)

                point(at: scaledPoint, color: UIColor.red, size: 4)
            }
        }
    }

    private func point(at point: CGPoint, color: UIColor, size: CGFloat) {
        let pointLayer = CALayer()
        pointLayer.backgroundColor = color.cgColor
        pointLayer.cornerRadius = size / 2
        pointLayer.frame = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        layer.addSublayer(pointLayer)
    }
}
