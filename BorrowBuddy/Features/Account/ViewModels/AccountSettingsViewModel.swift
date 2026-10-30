//
//  AccountSettingsViewModel.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class AccountSettingsViewModel: ObservableObject {
    @Published private(set) var account: AccountSummary?
    @Published var notifications = NotificationSettings.standard
    @Published var paymentMethod = "StoreKit 2"
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?

    func loadProfile(using repository: AccountRepository) async {
        await perform(allowConcurrent: false) {
            self.account = try await repository.loadAccount()
        }
    }

    func saveProfile(
        displayName: String,
        neighborhood: String,
        phoneNumber: String,
        using repository: AccountRepository
    ) async -> Bool {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNeighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = "Full name is required."
            successMessage = nil
            return false
        }
        guard !trimmedNeighborhood.isEmpty else {
            errorMessage = "Neighborhood is required."
            successMessage = nil
            return false
        }

        return await perform(allowConcurrent: true) {
            try await repository.updateProfile(
                displayName: trimmedName,
                neighborhood: trimmedNeighborhood,
                phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            self.account = try await repository.loadAccount()
            successMessage = "Profile saved."
        }
    }

    func loadNotifications(using repository: AccountRepository) async {
        await perform(allowConcurrent: false) {
            self.notifications = try await repository.loadNotificationSettings()
        }
    }

    func saveNotifications(using repository: AccountRepository) async -> Bool {
        await perform(allowConcurrent: false) {
            try await repository.updateNotificationSettings(notifications)
            successMessage = "Notification preferences saved."
        }
    }

    func loadPaymentMethod(using repository: AccountRepository) async {
        await perform(allowConcurrent: false) {
            self.paymentMethod = try await repository.loadPreferredPaymentMethod()
        }
    }

    func savePaymentMethod(using repository: AccountRepository) async -> Bool {
        await perform(allowConcurrent: false) {
            try await repository.updatePreferredPaymentMethod(paymentMethod)
            successMessage = "Payment preference saved."
        }
    }

    @discardableResult
    private func perform(
        allowConcurrent: Bool,
        _ operation: () async throws -> Void
    ) async -> Bool {
        if isLoading && !allowConcurrent {
            errorMessage = "Please wait a moment and try again."
            return false
        }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }
        do {
            try await operation()
            return true
        } catch {
            errorMessage = FriendlyError.clean(error.localizedDescription)
            return false
        }
    }
}
