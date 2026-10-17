//
//  OnboardingTwoView.swift
//  BorrowBuddy
//

import SwiftUI

struct OnboardingTwoView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.blue.opacity(0.08))
                    .frame(width: 160, height: 160)

                Image(systemName: "shield.checkered")
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
            }

            Text("Stay Safe & Covered.")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .multilineTextAlignment(.center)
                .padding(.top, 36)
                .padding(.horizontal, 28)

            Text("Verified neighbors, clear agreements, and\nprotections so every borrow feels secure.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()

            PrimaryButton(title: "Got it") {
                router.go(to: .signUp)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
