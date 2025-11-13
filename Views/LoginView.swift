//
//  LoginView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()
                WelcomeHeroBackground().opacity(0.6)

                VStack(spacing: 20) {
                    Text("Log in")
                        .font(.largeTitle.bold())
                        .gradientForeground()
                        .scaleEffect(appear ? 1.0 : 0.95)
                        .opacity(appear ? 1 : 0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: appear)

                    VStack(spacing: 12) {
                        TextField("Email", text: $email)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05), value: appear)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .opacity(appear ? 1 : 0)
                            .offset(y: appear ? 0 : 8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.1), value: appear)
                    }
                    .padding(.horizontal, 20)

                    if let error {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .transition(.opacity)
                    }

                    Button(isLoading ? "Signing in…" : "Log in") {
                        signIn()
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .buttonStyle(AtlasButtonStyle())
                    .padding(.horizontal, 20)

                    Button("Cancel") { dismiss() }
                        .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))
                        .padding(.horizontal, 20)
                }
            }
        }
        .onAppear { appear = true }
    }

    private func signIn() {
        isLoading = true
        error = nil

        // Stubbed success after a short delay. Replace with real auth later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            isLoading = false
            hasCompletedOnboarding = true
            dismiss()
        }
    }
}

