//
//  FaceIDSetupView.swift
//  BorrowBuddy
//

import SwiftUI

struct FaceIDSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var errorMessage: String?
    @State private var isEnabling = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(AppTheme.blue, lineWidth: 3)
                    .frame(width: 168, height: 168)

                Circle()
                    .stroke(AppTheme.blue.opacity(0.35), lineWidth: 2)
                    .frame(width: 118, height: 118)

                Image(systemName: "faceid")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(AppTheme.blue)
            }

            Text("Snappy Sign In")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 36)

            Text("Secure your tool shed with Face ID for fast and secure transactions.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.blue.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
            }

            Spacer()

            PrimaryButton(
                title: isEnabling ? "Waiting for Face ID..." : "Enable Face ID",
                enabled: !isEnabling
            ) {
                Task { await enableFaceID() }
            }
            .padding(.horizontal, 24)

            SecondaryButton(title: "Maybe Later", enabled: !isEnabling) {
                skipFaceID()
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .onAppear {
            if let message = BiometricAuthService.shared.availabilityMessage {
                errorMessage = message
            }
        }
    }

    private func enableFaceID() async {
        isEnabling = true
        errorMessage = nil
        defer { isEnabling = false }

        do {
            let success = try await BiometricAuthService.shared.authenticate(
                reason: "Enable Face ID so you can unlock BorrowBuddy quickly."
            )
            guard success else {
                errorMessage = "Face ID wasn't confirmed. Try again."
                return
            }

            if let credentials = dependencies.pendingCredentials {
                CredentialStore.save(credentials)
            }
            CredentialStore.isFaceIDEnabled = true
            dependencies.pendingCredentials = nil
            try? await dependencies.authenticationService.completeOnboarding()
            router.go(to: .home)
        } catch {
            // Stay on this screen — don't auto-skip so the user can retry or tap Maybe Later.
            errorMessage = error.localizedDescription
        }
    }

    private func skipFaceID() {
        CredentialStore.isFaceIDEnabled = false
        dependencies.pendingCredentials = nil
        router.go(to: .location)
    }
}
