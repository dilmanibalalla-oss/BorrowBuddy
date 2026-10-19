//
//  CreditHoldConfirmationViewModel.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-19.
//

import Combine
import LocalAuthentication

@MainActor
final class CreditHoldConfirmationViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func authorize(
        policy: LAPolicy,
        repository: BorrowingRepository,
        tool: BorrowingTool,
        quote: ReservationQuote
    ) async -> ReservationRecord? {
        guard !isLoading else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(policy, error: &availabilityError) else {
            errorMessage = policy == .deviceOwnerAuthenticationWithBiometrics
                ? "Face ID isn't available. Try your device passcode."
                : "Device authentication isn't available."
            return nil
        }

        do {
            let reason = "Authorize a refundable \(quote.totalHold) LendCredit hold"
            guard try await context.evaluatePolicy(policy, localizedReason: reason) else {
                errorMessage = "Authentication wasn't completed."
                return nil
            }
            return try await repository.createReservation(tool: tool, quote: quote)
        } catch {
            if let authenticationError = error as? LAError {
                switch authenticationError.code {
                case .authenticationFailed:
                    errorMessage = "Face ID didn't match. Nothing was charged."
                case .userCancel, .appCancel, .systemCancel:
                    errorMessage = "Authentication was cancelled. Nothing was charged."
                default:
                    errorMessage = authenticationError.localizedDescription
                }
            } else {
                errorMessage = error.localizedDescription
            }
            return nil
        }
    }
}
