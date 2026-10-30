import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct OfflineCacheTests {
    @Test func `Offline cache round trip`() throws {
        let store = OfflineCacheStore(inMemory: true)
        let account = AccountSummary(
            displayName: "Jordan",
            neighborhood: "Maple Grove",
            phoneNumber: "+1 555 0100",
            creditBalance: 42,
            creditHeld: 8,
            streetAddress: "12 Oak Street",
            identityVerified: true,
            addressConfirmed: true,
            isPro: true
        )
        store.saveAccount(account)
        let loaded = try #require(store.loadAccount())
        #expect(loaded.displayName == "Jordan")
        #expect(loaded.creditBalance == 42)
        #expect(loaded.isPro)
        #expect(loaded.identityVerified)

        store.saveTools([.demo])
        #expect(store.loadTools().map(\.name) == ["Cordless Drill"])

        let loan = sampleLoan()
        store.saveLoans([loan])
        #expect(store.loadLoans().map(\.toolName) == [loan.toolName])
    }

    private func sampleLoan(
        stage: LoanLifecycleStage = .active,
        status: ReservationStatus = .active
    ) -> ReservationRecord {
        ReservationRecord(
            id: "loan-1",
            receipt: "LC-1",
            toolID: BorrowingTool.demo.id,
            toolName: BorrowingTool.demo.name,
            ownerID: BorrowingTool.demo.ownerID,
            borrowerID: "borrower",
            pickupAt: Date(),
            returnAt: Date().addingTimeInterval(86_400),
            totalHold: 30,
            status: status,
            requestedAt: Date(),
            lifecycleStage: stage,
            toolSnapshot: BorrowingTool.demo
        )
    }
}
