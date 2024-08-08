//
//  UIView+.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/7/24.
//

import UIKit

extension UIView {

    public func drawPoint(at point: CGPoint, color: UIColor, size: CGFloat) {
        guard point.x >= .zero,
              point.y >= .zero,
              point.x <= frame.width,
              point.y <= frame.height else {
            return
        }

        let dotPath = UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: size, height: size))
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = dotPath.cgPath
        shapeLayer.fillColor = color.cgColor
        layer.addSublayer(shapeLayer)
    }
}
