//
//  RootView.swift
//  BorrowBuddy
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        Group {
            switch router.route {
            case .splash:
                SplashView()
            case .onboardingOne:
                OnboardingOneView()
            case .onboardingTwo:
                OnboardingTwoView()
            case .signUp:
                SignUpView()
            case .login:
                LoginView()
            case .signIn:
                PhoneSignInView()
            case .verification:
                VerificationView()
            case .faceID:
                FaceIDSetupView()
            case .location:
                LocationSetupView()
            case .home:
                DashboardView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: router.route)
        .task(id: dependencies.isAuthenticated) {
            await reconcileAuthState()
        }
    }

    private func reconcileAuthState() async {
        guard dependencies.isAuthenticated else {
            if router.route == .home {
                router.go(to: .signUp)
            }
            return
        }

        // Returning users who finished onboarding land on the dashboard.
        if router.route == .splash || router.route == .login || router.route == .signUp {
            do {
                if try await dependencies.authenticationService.hasCompletedOnboarding() {
                    router.go(to: .home)
                } else if router.route == .splash {
                    // Fresh session mid-onboarding — continue from phone step.
                    router.go(to: .signIn)
                }
            } catch {
                // Stay on the current screen if profile lookup fails.
            }
        }
    }
}
