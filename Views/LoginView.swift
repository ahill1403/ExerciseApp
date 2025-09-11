//
//  LoginView.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()

                VStack(spacing: 16) {
                    Text("Log in").font(.largeTitle.bold()).gradientForeground()

                    VStack(spacing: 12) {
                        TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 20)

                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }

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
