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
    case nearbyMap
    case toolDetails
    case reservationReview
    case reservationPending
    case wallet
    case calendar
    case profile
    case loanList
    case savedLocation
    case loanChat
    case baselineReview
    case baselineCapture
    case conditionGuide
    case pickupMeet
    case pickupConfirmed
    case activeLoan
    case toolReturn
    case arrivalConfirmed
    case returnCapture
    case compareCondition
    case ownerReview
    case loanCompleted
    case loanRating
    case helpSupport
    case nonReturnCase
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var route: AppRoute = .splash

    func go(to route: AppRoute) {
        self.route = route
    }
}
