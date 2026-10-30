//
//  SignUpViewModel.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class SignUpViewModel: ObservableObject {
    @Published var fullName = ""
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var canSubmit: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
            && password.count >= 6
            && !isLoading
    }

    func signUp(using service: AuthenticationService) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.signUp(
                fullName: fullName,
                email: email,
                password: password
            )
            return true
        } catch {
            errorMessage = mappedMessage(for: error)
            return false
        }
    }

    private func mappedMessage(for error: Error) -> String {
        let nsError = error as NSError
        if let authError = error as? AuthenticationError {
            return authError.localizedDescription
        }
        switch nsError.code {
        case 17007: // emailAlreadyInUse
            return "An account with this email already exists. Try logging in."
        case 17008: // invalidEmail
            return AuthenticationError.invalidEmail.localizedDescription
        case 17026: // weakPassword
            return AuthenticationError.weakPassword.localizedDescription
        case 17006: // operationNotAllowed
            return "Email sign-in isn't available right now. Try again later."
        case 17020: // networkError
            return "Network error. Check your connection and try again."
        default:
            return FriendlyError.clean(error.localizedDescription)
        }
    }
}
