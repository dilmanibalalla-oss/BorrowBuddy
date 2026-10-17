//
//  AppRouter.swift
//  BorrowBuddy
//

import Combine
import Foundation

enum AppRoute: Equatable {
    case splash
    case onboardingOne
    case onboardingTwo
    case signUp
    case login
    case signIn
    case verification
    case faceID
    case location
    case home
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var route: AppRoute = .splash

    func go(to route: AppRoute) {
        self.route = route
    }
}
