//
//  AccountViewModel.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class AccountViewModel: ObservableObject {
    @Published private(set) var account = AccountSummary(
        displayName: "Neighbor",
        neighborhood: "",
        phoneNumber: "",
        creditBalance: 0,
        creditHeld: 0
    )
    @Published private(set) var ledger: [WalletEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func apply(_ account: AccountSummary, cache: OfflineCacheStore? = nil) {
        self.account = account
        cache?.saveAccount(account)
    }

    func load(using repository: AccountRepository, cache: OfflineCacheStore? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedAccount = repository.loadAccount()
            async let loadedLedger = repository.loadLedger()
            account = try await loadedAccount
            ledger = try await loadedLedger
            cache?.saveAccount(account)
        } catch {
            if let cached = cache?.loadAccount() {
                account = cached
                errorMessage = "Showing your saved wallet while you're offline."
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearScheduleActivities(ids: [String], using repository: AccountRepository) async {
        let unique = Array(Set(ids.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return }
        do {
            try await repository.clearScheduleActivities(ids: unique)
            ledger.removeAll { unique.contains($0.id) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
