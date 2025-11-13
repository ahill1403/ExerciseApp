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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let motion = AtlasMotionPalette(reduceMotion: reduceMotion)

        ZStack {
            if hasCompletedOnboarding {
                AtlasTabRoot()
                    .transition(.opacity)
            } else {
                WelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(motion.crossfade, value: hasCompletedOnboarding)
        .environment(\.atlasMotion, motion)
    }
}

