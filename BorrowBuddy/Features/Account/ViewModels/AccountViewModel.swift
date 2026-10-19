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

    func load(using repository: AccountRepository) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedAccount = repository.loadAccount()
            async let loadedLedger = repository.loadLedger()
            account = try await loadedAccount
            ledger = try await loadedLedger
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
