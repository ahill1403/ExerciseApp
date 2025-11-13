//
//  REPSApp.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

@main
struct REPSApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            RootRouter()
        }
    }
}

private struct RootRouter: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                AtlasTabRoot()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: hasCompletedOnboarding)
    }
}

