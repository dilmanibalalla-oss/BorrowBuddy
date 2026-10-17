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
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

enum CommunityError: LocalizedError {
    case signInRequired

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            return "Please sign in to continue."
        }
    }
}
