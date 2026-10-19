//
//  AccountRepository.swift
//  BorrowBuddy
//

import Foundation

protocol AccountRepository: AnyObject {
    func loadAccount() async throws -> AccountSummary
    func loadLedger() async throws -> [WalletEntry]
    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws
    func updateProfilePhoto(_ data: Data) async throws
    func loadNotificationSettings() async throws -> NotificationSettings
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    func loadPreferredPaymentMethod() async throws -> String
    func updatePreferredPaymentMethod(_ method: String) async throws
}

final class DemoAccountRepository: AccountRepository {
    func loadAccount() async throws -> AccountSummary {
        AccountSummary(
            displayName: "Jordan Mitchell",
            neighborhood: "Maple Grove",
            phoneNumber: "+1 555 0100",
            creditBalance: 120,
            creditHeld: 0
        )
    }

    func loadLedger() async throws -> [WalletEntry] {
        [
            WalletEntry(id: "ladder", title: "Ladder Loan", detail: "Lent Ladder to Ned", credits: 15),
            WalletEntry(id: "tent", title: "Tent Loan", detail: "Lent Tent to Dan", credits: 20),
            WalletEntry(id: "drill", title: "Drill Borrow", detail: "Borrowed Cordless Drill", credits: -8),
            WalletEntry(id: "top-up", title: "Wallet Top-up", detail: "Starter Purchase via Card", credits: 50)
        ]
    }

    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws {}

    func updateProfilePhoto(_ data: Data) async throws {}

    func loadNotificationSettings() async throws -> NotificationSettings { .standard }

    func updateNotificationSettings(_ settings: NotificationSettings) async throws {}

    func loadPreferredPaymentMethod() async throws -> String { "Apple Pay" }

    func updatePreferredPaymentMethod(_ method: String) async throws {}
}
