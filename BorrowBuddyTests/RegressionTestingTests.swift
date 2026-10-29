import XCTest
@testable import BorrowBuddy

@MainActor
final class RegressionTestingTests: XCTestCase {
    func testPreviousVerificationCreditAndStoreBehavior() {
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        XCTAssertNil(verification.errorMessage)
        XCTAssertTrue(verification.canVerify)
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertNil(verification.errorMessage)
        XCTAssertTrue(verification.canVerify)

        let quote = ReservationQuote.make(for: .demo, days: 2)
        XCTAssertEqual(quote.totalHold, quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
        XCTAssertEqual(LendCreditMath.balance(afterHold: quote.totalHold, current: 100), 100 - quote.totalHold)
        XCTAssertNil(LendCreditMath.balance(afterHold: 40, current: 10))
        XCTAssertEqual(LendCreditMath.balance(afterPurchase: CreditPack.builder.credits, current: 20), 170)
        XCTAssertEqual(LoanSettlement(totalHold: 30, loanCharge: 18, depositRefund: 12).balanceChange, 12)

        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.starterProductID), 50)
        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.builderProductID), 150)
        XCTAssertNil(StoreCatalog.credits(for: StoreCatalog.proMonthlyProductID))
        XCTAssertEqual(MembershipPolicy.proWelcomeCredits, 10)
    }

    func testPreviousLoanLifecycleBehavior() {
        XCTAssertTrue(LoanLifecyclePolicy.canTransition(from: .active, to: .returnTransit))
        XCTAssertTrue(LoanLifecyclePolicy.canTransition(from: .returnInspection, to: .awaitingReview))
        XCTAssertFalse(LoanLifecyclePolicy.canTransition(from: .active, to: .completed))

        let now = Date()
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(48 * 3600), now: now), .upcoming)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(3 * 3600), now: now), .dueSoon)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-3600), now: now), .overdueGracePeriod)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-48 * 3600), now: now), .borrowingBlocked)
        XCTAssertEqual(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-8 * 24 * 3600), now: now), .escalationEligible)

        XCTAssertTrue(LoanRules.canVerifyArrival(distance: 50, accuracy: 10, age: 5))
        XCTAssertFalse(LoanRules.canVerifyArrival(distance: 51, accuracy: 10, age: 5))
        let loan = CoverageFixtures.loan()
        let region = DropOffRegionPolicy.region(for: loan)
        XCTAssertEqual(region?.radius, 50)
        XCTAssertEqual(region?.identifier, loan.id)
        XCTAssertFalse(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "someone-else"))
    }

    func testPreviousReminderAndCacheBehavior() throws {
        XCTAssertEqual(CalendarReminderPolicy.returnDayBefore, -24 * 60 * 60)
        XCTAssertEqual(CalendarReminderPolicy.returnTwoHoursBefore, -2 * 60 * 60)
        let returnAt = Date(timeIntervalSince1970: 1_700_000_000)
        let reminders = ReturnReminderSchedule.borrowerReturnReminders(returnAt: returnAt)
        XCTAssertEqual(reminders.map(\.suffix), ["return-day", "return-hour", "due", "overdue", "grace-ended"])
        XCTAssertEqual(reminders[0].fireAt, returnAt.addingTimeInterval(-86_400))
        XCTAssertEqual(reminders[4].fireAt, returnAt.addingTimeInterval(NonReturnPolicy.graceInterval))

        let store = OfflineCacheStore(inMemory: true)
        store.saveAccount(CoverageFixtures.account())
        let loaded = try XCTUnwrap(store.loadAccount())
        XCTAssertEqual(loaded.displayName, "Jordan")
        XCTAssertEqual(loaded.creditBalance, 42)
        store.saveTools([.demo])
        XCTAssertEqual(store.loadTools().map(\.name), ["Cordless Drill"])
    }
}
