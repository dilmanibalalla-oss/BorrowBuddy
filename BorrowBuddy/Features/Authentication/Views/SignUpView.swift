//
//  SignUpView.swift
//  BorrowBuddy
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = SignUpViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Create your account")
                    .font(AppTheme.rounded(28, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.top, 24)

                Text("Join your neighborhood tool shed in a minute.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 8)

                AuthTextField(
                    title: "Full Name",
                    placeholder: "Jordan Lee",
                    text: $viewModel.fullName,
                    kind: .name
                )
                .padding(.top, 28)

                AuthTextField(
                    title: "Email address",
                    placeholder: "you@email.com",
                    text: $viewModel.email,
                    kind: .email
                )
                .padding(.top, 16)

                AuthTextField(
                    title: "Create password",
                    placeholder: "At least 6 characters",
                    text: $viewModel.password,
                    kind: .newPassword
                )
                .padding(.top, 16)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.coral)
                        .padding(.top, 14)
                }

                PrimaryButton(
                    title: viewModel.isLoading ? "Creating..." : "Create account",
                    enabled: viewModel.canSubmit
                ) {
                    Task {
                        if await viewModel.signUp(using: dependencies.authenticationService) {
                            router.go(to: .signIn)
                        }
                    }
                }
                .padding(.top, 28)

                HStack {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                    Text("or")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(height: 1)
                }
                .padding(.vertical, 22)

                Button {
                    // Google Sign-In can be added with Firebase Auth + GoogleSignIn SDK.
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(AppTheme.blue)
                        Text("Sign up with Google")
                            .font(AppTheme.rounded(16, weight: .semibold))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.border, lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .disabled(true)
                .opacity(0.55)

                HStack(spacing: 4) {
                    Spacer()
                    Text("Already have an account?")
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Login") {
                        router.go(to: .login)
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.blue)
                    Spacer()
                }
                .font(.system(size: 15))
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background)
    }
}
