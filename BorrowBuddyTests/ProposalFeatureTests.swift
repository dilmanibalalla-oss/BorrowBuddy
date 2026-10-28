import CoreLocation
import XCTest
@testable import BorrowBuddy

@MainActor
final class ProposalFeatureTests: XCTestCase {
    func testLoginAcceptsTheLocalVerificationCode() {
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let model = VerificationViewModel()
        model.updateCode("000000")
        XCTAssertEqual(model.errorMessage, "Incorrect verification code.")
        XCTAssertFalse(model.canVerify)
        model.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.canVerify)
    }

    func testCreditBalanceMath() {
        let quote = ReservationQuote.make(for: .demo, days: 2)
        XCTAssertEqual(quote.totalHold, quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
        XCTAssertEqual(LendCreditMath.balance(afterHold: quote.totalHold, current: 100), 100 - quote.totalHold)
        XCTAssertNil(LendCreditMath.balance(afterHold: 40, current: 10))
        XCTAssertEqual(LendCreditMath.balance(afterPurchase: CreditPack.builder.credits, current: 20), 170)
        let settlement = LoanSettlement(totalHold: 30, loanCharge: 18, depositRefund: 12)
        XCTAssertEqual(settlement.balanceChange, 12)
    }

    func testRentalStateChanges() {
        XCTAssertTrue(LoanLifecyclePolicy.canTransition(from: .active, to: .returnTransit))
        XCTAssertTrue(LoanLifecyclePolicy.canTransition(from: .returnInspection, to: .awaitingReview))
        XCTAssertFalse(LoanLifecyclePolicy.canTransition(from: .active, to: .completed))

        let now = Date()
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(48 * 3600), now: now), .upcoming)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(3 * 3600), now: now), .dueSoon)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-3600), now: now), .overdueGracePeriod)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-48 * 3600), now: now), .borrowingBlocked)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-8 * 24 * 3600), now: now), .escalationEligible)
    }

    func testDropOffGeofenceIsFiftyMeters() {
        XCTAssertTrue(LoanRules.canVerifyArrival(distance: 50, accuracy: 10, age: 5))
        XCTAssertFalse(LoanRules.canVerifyArrival(distance: 51, accuracy: 10, age: 5))
        XCTAssertFalse(LoanRules.canVerifyArrival(distance: 20, accuracy: 150, age: 5))

        let loan = sampleLoan()
        let region = DropOffRegionPolicy.region(for: loan)
        XCTAssertEqual(region?.radius, 50)
        XCTAssertEqual(region?.identifier, loan.id)
        XCTAssertTrue(region?.notifyOnEntry == true)
        XCTAssertTrue(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "borrower"))
        XCTAssertFalse(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "someone-else"))
        XCTAssertFalse(DropOffRegionPolicy.shouldMonitor(sampleLoan(stage: .pending, status: .pending), borrowerID: "borrower"))
    }

    func testCalendarAndOverdueReminderOffsets() {
        XCTAssertEqual(CalendarReminderPolicy.returnDayBefore, -24 * 60 * 60)
        XCTAssertEqual(CalendarReminderPolicy.returnTwoHoursBefore, -2 * 60 * 60)
        let returnAt = Date(timeIntervalSince1970: 1_700_000_000)
        let reminders = ReturnReminderSchedule.borrowerReturnReminders(returnAt: returnAt)
        XCTAssertEqual(reminders.map(\.suffix), ["return-day", "return-hour", "due", "overdue", "grace-ended"])
        XCTAssertEqual(reminders[0].fireAt, returnAt.addingTimeInterval(-86_400))
        XCTAssertEqual(reminders[1].fireAt, returnAt.addingTimeInterval(-7_200))
        XCTAssertEqual(reminders[3].fireAt, returnAt.addingTimeInterval(60 * 60))
        XCTAssertEqual(reminders[4].fireAt, returnAt.addingTimeInterval(NonReturnPolicy.graceInterval))
    }

    func testOfflineCacheRoundTrip() throws {
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
        let loaded = try XCTUnwrap(store.loadAccount())
        XCTAssertEqual(loaded.displayName, "Jordan")
        XCTAssertEqual(loaded.creditBalance, 42)
        XCTAssertTrue(loaded.isPro)
        XCTAssertTrue(loaded.identityVerified)

        store.saveTools([.demo])
        XCTAssertEqual(store.loadTools().map(\.name), ["Cordless Drill"])

        let loan = sampleLoan()
        store.saveLoans([loan])
        XCTAssertEqual(store.loadLoans().map(\.toolName), [loan.toolName])
    }

    func testStoreKitCatalogAndProRules() {
        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.starterProductID), 50)
        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.builderProductID), 150)
        XCTAssertNil(StoreCatalog.credits(for: StoreCatalog.proMonthlyProductID))
        XCTAssertEqual(CreditPack.starter.productID, StoreCatalog.starterProductID)
        XCTAssertEqual(MembershipPolicy.proWelcomeCredits, 10)
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 0, isPro: false))
        XCTAssertFalse(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 1, isPro: false))
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 3, isPro: true))
        XCTAssertFalse(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: true))
        XCTAssertTrue(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: true))
    }

    func testEvidencePhotoKeepsADateStamp() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let stamped = EvidencePhotoStamp.apply(to: source, at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(stamped.size, source.size)
        XCTAssertNotNil(stamped.pngData())
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
