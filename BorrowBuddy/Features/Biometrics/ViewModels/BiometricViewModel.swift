//
//  BiometricViewModel.swift
//  BorrowBuddy
//

import Combine
import LocalAuthentication

@MainActor
final class BiometricViewModel: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var errorMessage: String?

    func refreshAvailability(policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics) {
        let context = LAContext()
        var error: NSError?
        isAvailable = context.canEvaluatePolicy(policy, error: &error)
        errorMessage = isAvailable ? nil : error?.localizedDescription
    }
}
