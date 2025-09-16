//
//  WelcomeView.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showOnboarding = false
    @State private var showLogin = false

    var body: some View {
        ZStack {
            NeonMotionBackground()

            VStack(spacing: 24) {
                Spacer()

                Text("AtlasFit").font(.system(size: 42, weight: .black, design: .rounded)).gradientForeground()

                Text("Strong Today.\nStronger Tomorrow.")
                    .multilineTextAlignment(.center)
                    .font(.title2.weight(.bold))

                Spacer()

                VStack(spacing: 12) {
                    Button("Start") { showOnboarding = true }
                        .buttonStyle(AtlasButtonStyle())

                    Button("Log in") { showLogin = true }
                        .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
    }
}

#Preview { WelcomeView()}
