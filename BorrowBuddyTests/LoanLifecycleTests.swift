import CoreLocation
import UIKit
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct LoanLifecycleTests {
    @Test func `Rental state changes`() {
        #expect(LoanLifecyclePolicy.canTransition(from: .active, to: .returnTransit))
        #expect(LoanLifecyclePolicy.canTransition(from: .returnInspection, to: .awaitingReview))
        #expect(!(LoanLifecyclePolicy.canTransition(from: .active, to: .completed)))

        let now = Date()
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(48 * 3600), now: now) == .upcoming)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(3 * 3600), now: now) == .dueSoon)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-3600), now: now) == .overdueGracePeriod)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-48 * 3600), now: now) == .borrowingBlocked)
        #expect(NonReturnPolicy.status(returnAt: now.addingTimeInterval(-8 * 24 * 3600), now: now) == .escalationEligible)
    }

    @Test func `Drop off geofence is fifty meters`() {
        #expect(LoanRules.canVerifyArrival(distance: 50, accuracy: 10, age: 5))
        #expect(!(LoanRules.canVerifyArrival(distance: 51, accuracy: 10, age: 5)))
        #expect(!(LoanRules.canVerifyArrival(distance: 20, accuracy: 150, age: 5)))

        let loan = sampleLoan()
        let region = DropOffRegionPolicy.region(for: loan)
        #expect(region?.radius == 50)
        #expect(region?.identifier == loan.id)
        #expect(region?.notifyOnEntry == true)
        #expect(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "borrower"))
        #expect(!(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "someone-else")))
        #expect(!(DropOffRegionPolicy.shouldMonitor(sampleLoan(stage: .pending, status: .pending), borrowerID: "borrower")))
    }

    @Test func `Calendar and overdue reminder offsets`() {
        #expect(CalendarReminderPolicy.returnDayBefore == -24 * 60 * 60)
        #expect(CalendarReminderPolicy.returnTwoHoursBefore == -2 * 60 * 60)
        let returnAt = Date(timeIntervalSince1970: 1_700_000_000)
        let reminders = ReturnReminderSchedule.borrowerReturnReminders(returnAt: returnAt)
        #expect(reminders.map(\.suffix) == ["return-day", "return-hour", "due", "overdue", "grace-ended"])
        #expect(reminders[0].fireAt == returnAt.addingTimeInterval(-86_400))
        #expect(reminders[1].fireAt == returnAt.addingTimeInterval(-7_200))
        #expect(reminders[3].fireAt == returnAt.addingTimeInterval(60 * 60))
        #expect(reminders[4].fireAt == returnAt.addingTimeInterval(NonReturnPolicy.graceInterval))
    }

    @Test func `Evidence photo keeps adate stamp`() {
        let source = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let stamped = EvidencePhotoStamp.apply(to: source, at: Date(timeIntervalSince1970: 1_700_000_000))
        #expect(stamped.size == source.size)
        #expect(stamped.pngData() != nil)
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
