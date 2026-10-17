//
//  FaceIDSetupView.swift
//  BorrowBuddy
//

import LocalAuthentication
import SwiftUI

struct FaceIDSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 72, weight: .regular))
                .foregroundStyle(AppTheme.blue)

            Text("Snappy Sign In")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 28)

            Text("Enable Face ID for faster, safer access\nthe next time you open BorrowBuddy.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 28)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 16)
            }

            Spacer()

            PrimaryButton(title: "Enable Face ID") {
                Task { await enableFaceID() }
            }
            .padding(.horizontal, 24)

            Button("Maybe Later") {
                router.go(to: .location)
            }
            .font(AppTheme.rounded(16, weight: .semibold))
            .foregroundStyle(AppTheme.blue)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private func enableFaceID() async {
        let context = LAContext()
        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) else {
            errorMessage = "Biometrics aren't available on this device."
            router.go(to: .location)
            return
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Enable Face ID for BorrowBuddy"
            )
            if success {
                UserDefaults.standard.set(true, forKey: "faceIDEnabled")
            }
            router.go(to: .location)
        } catch {
            errorMessage = "Face ID wasn't enabled. You can turn it on later in Settings."
            try? await Task.sleep(for: .milliseconds(800))
            router.go(to: .location)
        }
    }
}
