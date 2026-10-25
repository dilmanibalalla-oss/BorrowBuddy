//
//  AccountRepository.swift
//  BorrowBuddy
//

import Foundation

protocol AccountRepository: AnyObject {
    func loadAccount() async throws -> AccountSummary
    func loadLedger() async throws -> [WalletEntry]
    func loadScheduleEvents() async throws -> [ScheduleEvent]
    func syncScheduleEvents(for loans: [ReservationRecord]) async throws
    func clearScheduleActivities(ids: [String]) async throws
    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws
    func updateProfilePhoto(_ data: Data) async throws
    func loadNotificationSettings() async throws -> NotificationSettings
    func updateNotificationSettings(_ settings: NotificationSettings) async throws
    func loadPreferredPaymentMethod() async throws -> String
    func updatePreferredPaymentMethod(_ method: String) async throws
}

final class DemoAccountRepository: AccountRepository {
    private var clearedActivityIDs: Set<String> = []

    func loadAccount() async throws -> AccountSummary {
        AccountSummary(
            displayName: "Jordan Mitchell",
            neighborhood: "Maple Grove",
            phoneNumber: "+1 555 0100",
            creditBalance: AccountSummary.newAccountCredits,
            creditHeld: 0
        )
    }

    func loadLedger() async throws -> [WalletEntry] {
        let credits = [
            WalletEntry(id: "ladder", title: "Ladder Loan", detail: "Lent Ladder to Ned", credits: 15, recordedAt: Date().addingTimeInterval(-86_400)),
            WalletEntry(id: "tent", title: "Tent Loan", detail: "Lent Tent to Dan", credits: 20, recordedAt: Date().addingTimeInterval(-172_800)),
            WalletEntry(id: "drill", title: "Drill Borrow", detail: "Borrowed Cordless Drill", credits: -8, recordedAt: Date().addingTimeInterval(-250_000)),
            WalletEntry(id: "top-up", title: "Wallet Top-up", detail: "Starter Purchase via Card", credits: 50, recordedAt: Date().addingTimeInterval(-400_000))
        ]
        let activities = demoEvents
            .filter { !clearedActivityIDs.contains($0.id) }
            .map {
                WalletEntry(id: $0.id, title: $0.title, detail: $0.detail, credits: 0, kind: $0.kind, recordedAt: $0.occursAt)
            }
        return (credits + activities).sorted { $0.recordedAt > $1.recordedAt }
    }

    func loadScheduleEvents() async throws -> [ScheduleEvent] {
        demoEvents
    }

    func syncScheduleEvents(for loans: [ReservationRecord]) async throws {}

    func clearScheduleActivities(ids: [String]) async throws {
        clearedActivityIDs.formUnion(ids)
    }

    private var demoEvents: [ScheduleEvent] {
        [
            ScheduleEvent(
                id: "demo_pickup",
                kind: .pickup,
                reservationID: "demo",
                title: "Pickup · Cordless Drill",
                detail: "Pick up from Alex",
                occursAt: Date().addingTimeInterval(86_400),
                address: "12 Oak Street",
                loanStatus: ReservationStatus.pending.rawValue
            ),
            ScheduleEvent(
                id: "demo_return",
                kind: .return,
                reservationID: "demo",
                title: "Return · Cordless Drill",
                detail: "Return to Alex",
                occursAt: Date().addingTimeInterval(3 * 86_400),
                address: "12 Oak Street",
                loanStatus: ReservationStatus.pending.rawValue
            )
        ]
    }

    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws {}

    func updateProfilePhoto(_ data: Data) async throws {}

    func loadNotificationSettings() async throws -> NotificationSettings { .standard }

    func updateNotificationSettings(_ settings: NotificationSettings) async throws {}

    func loadPreferredPaymentMethod() async throws -> String { "Apple Pay" }

    func updatePreferredPaymentMethod(_ method: String) async throws {}
}
