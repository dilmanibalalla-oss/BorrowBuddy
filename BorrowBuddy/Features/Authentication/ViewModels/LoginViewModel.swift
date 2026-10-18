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

    var canUseFaceID: Bool {
        CredentialStore.isFaceIDEnabled
            && CredentialStore.hasStoredCredentials
            && !isLoading
    }

    func signIn(using service: AuthenticationService) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await service.signIn(email: email, password: password)
            if CredentialStore.isFaceIDEnabled {
                CredentialStore.save(StoredCredentials(email: email, password: password))
            }
            return true
        } catch {
            errorMessage = mappedMessage(for: error)
            return false
        }
    }

    func signInWithFaceID(using service: AuthenticationService) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let credentials = CredentialStore.load() else {
            errorMessage = "No saved Face ID credentials. Log in with email once after enabling Face ID."
            return false
        }

        do {
            let success = try await BiometricAuthService.shared.authenticate(
                reason: "Sign in to BorrowBuddy with \(BiometricAuthService.shared.biometryTypeName)"
            )
            guard success else {
                errorMessage = "Face ID was cancelled."
                return false
            }
            try await service.signIn(email: credentials.email, password: credentials.password)
            email = credentials.email
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func mappedMessage(for error: Error) -> String {
        let nsError = error as NSError
        if let authError = error as? AuthenticationError {
            return authError.localizedDescription
        }
        switch nsError.code {
        case 17004, 17009:
            return "Incorrect email or password."
        case 17011:
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
