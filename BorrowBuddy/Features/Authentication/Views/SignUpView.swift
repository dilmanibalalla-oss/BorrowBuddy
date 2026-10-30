//
//  SignUpView.swift
//  BorrowBuddy
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = SignUpViewModel()
    @State private var isGoogleLoading = false
    @State private var googleError: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Create your account")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.onYellow)
                Text("Join your neighborhood tool shed in a minute.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.onYellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.yellow)

            GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    signUpArtwork(width: proxy.size.width)
                        .padding(.top, 12)

                    AuthTextField(
                        title: "Full Name",
                        placeholder: "Jordan Lee",
                        text: $viewModel.fullName,
                        kind: .name,
                        autofocus: true
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
                        DismissingErrorText(message: errorMessage, centered: true, topPadding: 14)
                    }

                    PrimaryButton(
                        title: viewModel.isLoading ? "Creating..." : "Create account",
                        enabled: viewModel.canSubmit
                    ) {
                        Task {
                            if await viewModel.signUp(using: dependencies.authenticationService) {
                                dependencies.pendingCredentials = StoredCredentials(
                                    email: viewModel.email,
                                    password: viewModel.password
                                )
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
                        Task { await signUpWithGoogle() }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(AppTheme.blue)
                            Text(isGoogleLoading ? "Opening Google..." : "Sign up with Google")
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
                    .disabled(isGoogleLoading || viewModel.isLoading)
                    .accessibilityLabel("Sign up with Google")

                    if let googleError {
                        DismissingErrorText(message: googleError, centered: true, topPadding: 12)
                    }

                    HStack(spacing: 4) {
                        Text("Already have an account?")
                            .foregroundStyle(AppTheme.secondaryText)
                        Button("Login") {
                            router.go(to: .login)
                        }
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.blue)
                    }
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 28)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private func signUpArtwork(width: CGFloat) -> some View {
        let wide = width >= 700
        let artWidth = wide ? min(width - 48, 460) : min(max(width - 48, 160), 320)
        return Image("SignInArtwork")
            .resizable()
            .scaledToFit()
            .frame(width: artWidth, height: wide ? 260 : 180)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Neighbor browsing shared tools")
            .accessibilityAddTraits(.isImage)
    }

    private func signUpWithGoogle() async {
        isGoogleLoading = true
        googleError = nil
        defer { isGoogleLoading = false }
        do {
            try await dependencies.authenticationService.signInWithGoogle()
            if try await dependencies.authenticationService.hasCompletedOnboarding() {
                router.go(to: .home)
            } else {
                router.go(to: .signIn)
            }
        } catch {
            googleError = error.localizedDescription
        }
    }
}
