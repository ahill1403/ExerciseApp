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
            AtlasTabRoot()
        }
    }
}

private struct RootRouter: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if hasCompletedOnboarding {
                // ✅ After onboarding, load the tabbed root (with center Home button)
                AtlasTabRoot()
                    .transition(.opacity)
            } else {
                // ✅ Your existing welcome/onboarding entry
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 3.00), value: hasCompletedOnboarding)
    }
}
