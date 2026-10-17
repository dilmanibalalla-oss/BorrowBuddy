//
//  PhoneSignInView.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import SwiftUI

struct PhoneSignInView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = PhoneSignInViewModel()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .onboardingTwo)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            Spacer()

            Text("Welcome, Neighbor!")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            Text("Join BorrowBuddy. Enter your phone number\nto get verified.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .padding(.top, 7)

            Text("PHONE NUMBER")
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 28)

            HStack(spacing: 12) {
                Text("🇱🇰")
                    .font(.system(size: 22))

                Text("+94")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.text)

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 28)

                TextField("11 234 5678", text: Binding(
                    get: { viewModel.phoneNumber },
                    set: viewModel.format
                ))
                .keyboardType(.numberPad)
                .font(.system(size: 17))
                .focused($isFocused)
                .accessibilityLabel("Phone number")
            }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.blue, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .padding(.top, 7)

            Text("By continuing, you agree to receive a single automated SMS\nverification code. Carrier rates may apply.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .padding(.top, 17)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 12)
            }

            Spacer()

            PrimaryButton(
                title: viewModel.isLoading ? "Sending..." : "Send Verification Code",
                enabled: viewModel.canContinue && !viewModel.isLoading
            ) {
                Task {
                    if let verificationID = await viewModel.sendCode(
                        using: dependencies.authenticationService
                    ) {
                        dependencies.verificationID = verificationID
                        dependencies.verificationPhoneNumber = viewModel.displayPhoneNumber
                        router.go(to: .verification)
                    }
                }
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .onAppear {
            isFocused = true
        }
    }
}
