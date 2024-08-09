//
//  ContentScreen.swift
//  MovenetOptimizationExample
//
//  Created by Hong Seong Ho on 8/6/24.
//

import SwiftUI

struct ContentScreen: View {

    @State private var isRecording = false

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: OriginMovenetScreen(time: "")) {
                    Text("기존 Movenet 예제")
                }
                NavigationLink(destination: MovenetOptimizationScreen(time: "")) {
                    Text("MovenetOptimization 이용")
                }
            }
            .navigationBarTitle("Movenet Options")
        }
    }
}

struct ContentScreen_Previews: PreviewProvider {
    static var previews: some View {
        ContentScreen()
    }
}

#Preview {
    ContentScreen()
}
