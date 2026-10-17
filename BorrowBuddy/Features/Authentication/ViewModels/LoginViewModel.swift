//
//  LoginViewModel.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var canSubmit: Bool {
        email.contains("@") && password.count >= 6 && !isLoading
    }

    func signIn(using service: AuthenticationService) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.signIn(email: email, password: password)
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
        case 17004, 17009: // wrong password / invalid credential
            return "Incorrect email or password."
        case 17011: // userNotFound
            return "No account found with that email."
        case 17008:
            return AuthenticationError.invalidEmail.localizedDescription
        case 17020:
            return "Network error. Check your connection and try again."
        default:
            return error.localizedDescription
        }
    }
}
