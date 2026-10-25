//
//  BorrowingFlowStore.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class BorrowingFlowStore: ObservableObject {
    @Published var selectedTool: BorrowingTool = .demo
    @Published var quote: ReservationQuote = .make(for: .demo)
    @Published var reservation: ReservationRecord?

    func select(_ tool: BorrowingTool) {
        selectedTool = tool
        let returnDay = tool.availableUntil ?? Self.pickupDate(for: tool).addingTimeInterval(2 * 86_400)
        quote = Self.quote(for: tool, returnDay: returnDay)
    }

    func selectPickupDay(_ date: Date) {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        if let from = selectedTool.availableFrom, day < calendar.startOfDay(for: from) { return }
        if let until = selectedTool.availableUntil, day > calendar.startOfDay(for: until) { return }
        let pickupDay = calendar.startOfDay(for: Self.pickupDate(for: selectedTool))
        guard day >= pickupDay else { return }
        quote = Self.quote(for: selectedTool, returnDay: day)
    }

    /// Pickup stays on the owner's start date. The tapped day becomes the return date.
    private static func quote(for tool: BorrowingTool, returnDay: Date) -> ReservationQuote {
        let calendar = Calendar.current
        let pickup = pickupDate(for: tool)
        let chosen = calendar.startOfDay(for: returnDay)
        let returning: Date
        if chosen <= calendar.startOfDay(for: pickup) {
            returning = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: pickup))?.addingTimeInterval(-60)
                ?? pickup.addingTimeInterval(3600)
        } else {
            returning = chosen
        }
        let days = max(
            1,
            calendar.dateComponents([.day], from: calendar.startOfDay(for: pickup), to: calendar.startOfDay(for: returning)).day ?? 1
        )
        return ReservationQuote(
            pickupAt: pickup,
            returnAt: returning > pickup ? returning : pickup.addingTimeInterval(3600),
            rentalCredits: tool.dailyCredits * days,
            serviceCredits: 2,
            depositCredits: tool.depositCredits
        )
    }

    private static func pickupDate(for tool: BorrowingTool) -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        var pickup = tool.availableFrom.map { calendar.startOfDay(for: $0) } ?? tomorrow
        if let until = tool.availableUntil, pickup > calendar.startOfDay(for: until) {
            pickup = calendar.startOfDay(for: until)
        }
        if pickup <= Date() {
            pickup = Date().addingTimeInterval(60)
        }
        return pickup
    }
}

@MainActor
final class CommunityViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var error: String?
    @Published var success: String?
    @Published private(set) var account = AccountSummary(
        displayName: "",
        neighborhood: "",
        phoneNumber: "",
        creditBalance: 0,
        creditHeld: 0
    )
    @Published private(set) var loans: [ReservationRecord] = []
    @Published private(set) var nearbyTools: [BorrowingTool] = []
    @Published private(set) var ledger: [WalletEntry] = []
    @Published private(set) var sectionErrors: [String: String] = [:]

    func load(using dependencies: AppDependencies) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        sectionErrors = [:]
        defer { isLoading = false }

        do {
            account = try await dependencies.accountRepository.loadAccount()
        } catch {
            self.error = error.localizedDescription
        }

        do {
            nearbyTools = try await dependencies.borrowingRepository.fetchNearbyTools()
        } catch {
            sectionErrors["Nearby tools"] = error.localizedDescription
        }

        do {
            loans = try await dependencies.borrowingRepository.fetchMyLoans()
            do {
                try await dependencies.accountRepository.syncScheduleEvents(for: loans)
            } catch {
                sectionErrors["Schedule"] = error.localizedDescription
            }
        } catch {
            sectionErrors["Loan history"] = error.localizedDescription
        }

        do {
            ledger = try await dependencies.accountRepository.loadLedger()
        } catch {
            sectionErrors["Wallet activity"] = error.localizedDescription
        }
    }

    @discardableResult
    func perform(_ operation: () async throws -> Void) async -> Bool {
        guard !isLoading else { return false }
        isLoading = true
        error = nil
        success = nil
        defer { isLoading = false }
        do {
            try await operation()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

protocol CommunityRepository: AnyObject {
    func respond(reservationID: String, accepted: Bool) async throws
    func cancel(reservationID: String) async throws
    func saveAddress(street: String, unit: String, postalCode: String, latitude: Double, longitude: Double) async throws
    func acknowledgePickup(reservationID: String) async throws
    func recordArrival(reservationID: String, accuracy: Double) async throws
    func flagReturn(reservationID: String, reason: String) async throws
    func myRating(reservationID: String) async throws -> LoanRating?
    func submitRating(reservationID: String, rating: LoanRating) async throws
    func requestExtension(reservationID: String, returnAt: Date) async throws
    func respondToExtension(reservationID: String, accepted: Bool) async throws
    func postLoanNote(reservationID: String, message: String) async throws
    func loanNotes(reservationID: String) async throws -> [LoanNote]
    func loanNoteUpdates(reservationID: String) -> AsyncThrowingStream<[LoanNote], Error>
}

final class DemoCommunityRepository: CommunityRepository {
    func respond(reservationID: String, accepted: Bool) async throws {}
    func cancel(reservationID: String) async throws {}
    func saveAddress(street: String, unit: String, postalCode: String, latitude: Double, longitude: Double) async throws {}
    func acknowledgePickup(reservationID: String) async throws {}
    func recordArrival(reservationID: String, accuracy: Double) async throws {}
    func flagReturn(reservationID: String, reason: String) async throws {}
    func myRating(reservationID: String) async throws -> LoanRating? { nil }
    func submitRating(reservationID: String, rating: LoanRating) async throws {}
    func requestExtension(reservationID: String, returnAt: Date) async throws {}
    func respondToExtension(reservationID: String, accepted: Bool) async throws {}
    func postLoanNote(reservationID: String, message: String) async throws {}
    func loanNotes(reservationID: String) async throws -> [LoanNote] { [] }
    func loanNoteUpdates(reservationID: String) -> AsyncThrowingStream<[LoanNote], Error> {
        AsyncThrowingStream { continuation in
            continuation.yield([])
            continuation.finish()
        }
    }
}
