//
//  WelcomeView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var showOnboarding = false
    @State private var showLogin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appear = false
    @State private var shimmer = false

    var body: some View {
        ZStack {
            NeonMotionBackground()
            WelcomeHeroBackground()

            VStack(spacing: 24) {
                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    Text("REPS")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .gradientForeground()
                        .scaleEffect(appear ? 1.0 : 0.9)
                        .opacity(appear ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05), value: appear)

                    Text("Strong Today.\nStronger Tomorrow.")
                        .multilineTextAlignment(.center)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AtlasTheme.textPrimary)
                        .offset(y: appear ? 0 : 8)
                        .opacity(appear ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.85).delay(0.12), value: appear)
                }

                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Button("Start") { showOnboarding = true }
                        .buttonStyle(AtlasButtonStyle())
                        .overlay(shimmerOverlay.mask(RoundedRectangle(cornerRadius: 16, style: .continuous)))
                        .onAppear {
                            if !reduceMotion {
                                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                                    shimmer.toggle()
                                }
                            }
                        }

                    Button("Log in") { showLogin = true }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AtlasTheme.gradientAlt.opacity(0.16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12))
                        )
                        .foregroundStyle(AtlasTheme.textPrimary)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 6)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .padding()
        }
        .onAppear { appear = true }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                colors: [
                    .white.opacity(0.0),
                    .white.opacity(0.35),
                    .white.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width)
            .offset(x: shimmer ? width : -width)
        }
    }
}

struct WelcomeHeroBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    @State private var drift = false

    var body: some View {
        ZStack {
            // Large breathing blobs
            Circle()
                .fill(AtlasTheme.gradient)
                .frame(width: 520, height: 520)
                .scaleEffect(breathe ? 1.06 : 0.94)
                .blur(radius: 40)
                .opacity(0.28)
                .offset(y: -80)

            Circle()
                .fill(AtlasTheme.gradientAlt)
                .frame(width: 360, height: 360)
                .scaleEffect(breathe ? 0.96 : 1.04)
                .blur(radius: 32)
                .opacity(0.24)
                .offset(y: 120)

            // Gentle drifting ring
            Circle()
                .strokeBorder(AtlasTheme.accentGreen.opacity(0.22), lineWidth: 2)
                .frame(width: 420, height: 420)
                .scaleEffect(drift ? 1.03 : 0.97)
                .blur(radius: 2)
                .opacity(0.5)
                .offset(y: -10)

            // Subtle sparkles
            SparkleField()
        }
        .allowsHitTesting(false)
        .animation(reduceMotion ? nil : .easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: breathe)
        .animation(reduceMotion ? nil : .easeInOut(duration: 6.4).repeatForever(autoreverses: true), value: drift)
        .onAppear {
            if !reduceMotion {
                breathe = true
                drift = true
            }
        }
    }
}

struct SparkleField: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let slow = CGFloat(sin(t / 2.0))
            let fast = CGFloat(sin(t * 1.6))
            ZStack {
                ForEach(0..<16, id: \.self) { i in
                    let angle = CGFloat(i) / 16.0 * .pi * 2
                    let radius: CGFloat = 140 + 60 * CGFloat((i % 5))
                    let x = cos(angle + slow * 0.2) * radius
                    let y = sin(angle + fast * 0.2) * radius
                    Circle()
                        .fill(AtlasTheme.accentGreen.opacity(0.15))
                        .frame(width: 4, height: 4)
                        .blur(radius: 0.5)
                        .offset(x: x, y: y)
                        .opacity(0.6 + 0.4 * Double(sin(t + Double(i))))
                }
            }
        }
        .opacity(reduceMotion ? 0.2 : 0.6)
    }
}

#Preview { WelcomeView()}
