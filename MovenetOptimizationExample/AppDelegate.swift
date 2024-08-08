//
//  AppDelegate.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/7/24.
//

import UIKit
import MovenetOptimization

class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        MovenetEngine.shared.initialize(completion: { _ in })
        return true
    }
}
