//
//  SplashView.swift
//  BorrowBuddy
//

import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppTheme.yellow)
                    .frame(width: 108, height: 108)
                    .shadow(color: AppTheme.yellow.opacity(0.35), radius: 18, y: 8)

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
            }

            Text("BorrowBuddy")
                .font(AppTheme.rounded(34, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .task {
            try? await Task.sleep(for: .milliseconds(1200))
            guard !Task.isCancelled else { return }

            if dependencies.isAuthenticated {
                do {
                    if try await dependencies.authenticationService.hasCompletedOnboarding() {
                        router.go(to: .home)
                        return
                    }
                    router.go(to: .signIn)
                    return
                } catch {
                    router.go(to: .onboardingOne)
                    return
                }
            }

            router.go(to: .onboardingOne)
        }
    }
}
