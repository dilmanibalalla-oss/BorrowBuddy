//
//  AppErrors.swift
//  BorrowBuddy
//

import Foundation

enum AuthenticationError: LocalizedError {
    case invalidEmail
    case weakPassword
    case emptyFields
    case invalidCode
    case verificationNotStarted
    case signInRequired
    case biometricsUnavailable
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .emptyFields:
            return "Please fill in all required fields."
        case .invalidCode:
            return "Enter the 6-digit verification code."
        case .verificationNotStarted:
            return "Request a verification code first."
        case .signInRequired:
            return "Please sign in to continue."
        case .biometricsUnavailable:
            return "Face ID isn't available on this device."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

enum CommunityError: LocalizedError {
    case signInRequired
    case profileMissing
    case unavailable
    case invalidInput(String)
    case wrongRole
    case blocked
    case expiredLocation
    case invalidStep

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            return "Please sign in to continue."
        case .profileMissing:
            return "Couldn't find your account profile."
        case .unavailable:
            return "This action isn't available right now."
        case .invalidInput(let message):
            return message
        case .wrongRole:
            return "You can't borrow your own listing."
        case .blocked:
            return "Borrowing is temporarily blocked on this account."
        case .expiredLocation:
            return "Move closer to the drop-off and refresh your location before confirming arrival."
        case .invalidStep:
            return "This loan step cannot be completed yet."
        }
    }
}
