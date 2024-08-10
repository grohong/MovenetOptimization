//
//  MovenetOptimizationScreen.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/6/24.
//

import SwiftUI

struct MovenetOptimizationScreen: View {

    @StateObject private var performanceMonitor = PerformanceMonitor()
    @State var time: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraViewRepresentable(
                isUseOpenCVPreprocessor: true,
                updateTotalTime: { self.time = $0 }
            )
                .edgesIgnoringSafeArea(.all)

            VStack(alignment: .leading, spacing: 10) {
                Text("CPU : \(String(format: "%.2f", performanceMonitor.cpuUsage))%")
                    .foregroundColor(.white)
                Text("Memory : \(String(format: "%.1f", performanceMonitor.memoryUsage))MB")
                    .foregroundColor(.white)
                Text("time : \(time)")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color.gray.opacity(0.7))
            .cornerRadius(10)
            .padding(.top, 10)
            .padding(.leading, 10)
        }
        .navigationBarTitle("MovenetOptimization 이용", displayMode: .inline)
    }
}
