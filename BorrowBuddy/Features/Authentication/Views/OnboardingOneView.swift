//
//  OnboardingOneView.swift
//  BorrowBuddy
//

import SwiftUI

struct OnboardingOneView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.yellow.opacity(0.2))
                    .frame(width: 160, height: 160)

                BorrowBuddyLogo(size: 120)
            }

            Text("Share Tools, Earn Credits.")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .multilineTextAlignment(.center)
                .padding(.top, 36)
                .padding(.horizontal, 28)

            Text("Lend what you own, borrow what you need,\nand build neighborhood trust with credits.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 12)
                .padding(.horizontal, 32)

            Spacer()

            PrimaryButton(title: "Next") {
                router.go(to: .onboardingTwo)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
