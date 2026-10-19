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
        quote = .make(for: tool)
    }

    func selectPickupDay(_ date: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let days = max(
            1,
            calendar.dateComponents([.day], from: calendar.startOfDay(for: quote.pickupAt), to: calendar.startOfDay(for: quote.returnAt)).day ?? 2
        )
        quote = .make(for: selectedTool, pickupAt: start, days: days)
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
            ledger = try await dependencies.accountRepository.loadLedger()
        } catch {
            sectionErrors["Wallet activity"] = error.localizedDescription
        }

        do {
            nearbyTools = try await dependencies.borrowingRepository.fetchNearbyTools()
        } catch {
            sectionErrors["Nearby tools"] = error.localizedDescription
        }

        do {
            loans = try await dependencies.borrowingRepository.fetchMyLoans()
        } catch {
            sectionErrors["Loan history"] = error.localizedDescription
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
}
