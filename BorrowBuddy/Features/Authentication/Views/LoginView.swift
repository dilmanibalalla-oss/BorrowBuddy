//
//  LoginView.swift
//  BorrowBuddy
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .signUp)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            Text("Welcome back")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 12)

            Text("Log in with your email and password, or unlock with Face ID.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.top, 8)

            AuthTextField(
                title: "Email address",
                placeholder: "you@email.com",
                text: $viewModel.email,
                kind: .email,
                autofocus: true
            )
            .padding(.top, 28)

            AuthTextField(
                title: "Password",
                placeholder: "Your password",
                text: $viewModel.password,
                kind: .password
            )
            .padding(.top, 16)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 14)
            }

            Spacer()

            if viewModel.canUseFaceID {
                PrimaryButton(
                    title: viewModel.isLoading ? "Unlocking..." : "Sign in with Face ID",
                    systemImage: "faceid",
                    enabled: !viewModel.isLoading
                ) {
                    Task {
                        if await viewModel.signInWithFaceID(using: dependencies.authenticationService) {
                            try? await dependencies.authenticationService.completeOnboarding()
                            router.go(to: .home)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            PrimaryButton(
                title: viewModel.isLoading ? "Logging in..." : "Log in",
                enabled: viewModel.canSubmit
            ) {
                Task {
                    if await viewModel.signIn(using: dependencies.authenticationService) {
                        try? await dependencies.authenticationService.completeOnboarding()
                        router.go(to: .home)
                    }
                }
            }
            .padding(.bottom, 8)

            HStack(spacing: 4) {
                Spacer()
                Text("New here?")
                    .foregroundStyle(AppTheme.secondaryText)
                Button("Create account") {
                    router.go(to: .signUp)
                }
                .fontWeight(.bold)
                .foregroundStyle(AppTheme.blue)
                Spacer()
            }
            .font(.system(size: 15))
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
