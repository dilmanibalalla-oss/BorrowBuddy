//
//  LoginView.swift
//  BorrowBuddy
//

import SwiftUI

struct LoginView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.onYellow)
                Text("Log in with your email and password, or unlock with Face ID.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.onYellow)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.yellow)

            loginArtwork
                .padding(.top, 12)

            BackButton {
                router.go(to: .signUp)
            }
            .padding(.top, 8)
            .padding(.leading, 6)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 12)

            VStack(spacing: 0) {
                AuthTextField(
                    title: "Email address",
                    placeholder: "you@email.com",
                    text: $viewModel.email,
                    kind: .email,
                    autofocus: true
                )

                AuthTextField(
                    title: "Password",
                    placeholder: "Your password",
                    text: $viewModel.password,
                    kind: .password
                )
                .padding(.top, 16)

                if let errorMessage = viewModel.errorMessage {
                    DismissingErrorText(message: errorMessage, centered: true, topPadding: 14)
                }

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
                    .padding(.top, 28)
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
                .padding(.top, viewModel.canUseFaceID ? 12 : 28)

                HStack(spacing: 4) {
                    Text("New here?")
                        .foregroundStyle(AppTheme.secondaryText)
                    Button("Create account") {
                        router.go(to: .signUp)
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(AppTheme.blue)
                }
                .font(.system(size: 15))
                .frame(maxWidth: .infinity)
                .padding(.top, 18)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 18)
        }
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        #if targetEnvironment(simulator)
        .overlay {
            if viewModel.isPresentingFaceID {
                simulatorFaceIDScreen
            }
        }
        #endif
    }

    #if targetEnvironment(simulator)
    private var simulatorFaceIDScreen: some View {
        ZStack {
            Color(white: 0.62)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "faceid")
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color(white: 0.15))
                Text("Face ID")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color(white: 0.15))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Face ID")
        .accessibilityAddTraits(.isImage)
    }
    #endif

    private var loginArtwork: some View {
        let wide = horizontalSizeClass == .regular
        return Image("LoginArtwork")
            .resizable()
            .scaledToFit()
            .frame(width: wide ? 420 : 280, height: wide ? 250 : 170)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Neighbors confirming a tool request")
            .accessibilityAddTraits(.isImage)
    }
}
