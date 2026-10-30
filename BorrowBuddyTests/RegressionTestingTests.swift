import CoreLocation
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct RegressionTestingTests {
    @Test func `Previous verification credit and store behavior`() {
        #expect(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        #expect(verification.errorMessage == nil)
        #expect(verification.canVerify)
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        #expect(verification.errorMessage == nil)
        #expect(verification.canVerify)

        let quote = ReservationQuote.make(for: .demo, days: 2)
        #expect(quote.totalHold == quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
        #expect(LendCreditMath.balance(afterHold: quote.totalHold, current: 100) == 100 - quote.totalHold)
        #expect(LendCreditMath.balance(afterHold: 40, current: 10) == nil)
        #expect(LendCreditMath.balance(afterPurchase: CreditPack.builder.credits, current: 20) == 170)
        #expect(LoanSettlement(totalHold: 30, loanCharge: 18, depositRefund: 12).balanceChange == 12)

        #expect(StoreCatalog.credits(for: StoreCatalog.starterProductID) == 50)
        #expect(StoreCatalog.credits(for: StoreCatalog.builderProductID) == 150)
        #expect(StoreCatalog.credits(for: StoreCatalog.proMonthlyProductID) == nil)
        #expect(MembershipPolicy.proWelcomeCredits == 10)
    }

    @Test func `Previous loan lifecycle behavior`() {
        #expect(LoanLifecyclePolicy.canTransition(from: .active, to: .returnTransit))
        #expect(LoanLifecyclePolicy.canTransition(from: .returnInspection, to: .awaitingReview))
        #expect(!(LoanLifecyclePolicy.canTransition(from: .active, to: .completed)))

        let now = Date()
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(48 * 3600), now: now) == .upcoming)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(3 * 3600), now: now) == .dueSoon)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-3600), now: now) == .overdueGracePeriod)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-48 * 3600), now: now) == .borrowingBlocked)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-8 * 24 * 3600), now: now) == .escalationEligible)

        #expect(LoanRules.canVerifyArrival(distance: 50, accuracy: 10, age: 5))
        #expect(!(LoanRules.canVerifyArrival(distance: 51, accuracy: 10, age: 5)))
        let loan = CoverageFixtures.loan()
        let region = DropOffRegionPolicy.region(for: loan)
        #expect(region?.radius == 50)
        #expect(region?.identifier == loan.id)
        #expect(!(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "someone-else")))
    }

    @Test func `Previous reminder and cache behavior`() throws {
        #expect(CalendarReminderPolicy.returnDayBefore == -24 * 60 * 60)
        #expect(CalendarReminderPolicy.returnTwoHoursBefore == -2 * 60 * 60)
        let returnAt = Date(timeIntervalSince1970: 1_700_000_000)
        let reminders = ReturnReminderSchedule.borrowerReturnReminders(returnAt: returnAt)
        #expect(reminders.map(\.suffix) == ["return-day", "return-hour", "due", "overdue", "grace-ended"])
        #expect(reminders[0].fireAt == returnAt.addingTimeInterval(-86_400))
        #expect(reminders[4].fireAt == returnAt.addingTimeInterval(NonReturnPolicy.graceInterval))

        let store = OfflineCacheStore(inMemory: true)
        store.saveAccount(CoverageFixtures.account())
        let loaded = try #require(store.loadAccount())
        #expect(loaded.displayName == "Jordan")
        #expect(loaded.creditBalance == 42)
        store.saveTools([.demo])
        #expect(store.loadTools().map(\.name) == ["Cordless Drill"])
    }
}
