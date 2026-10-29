import CoreLocation
import UIKit
import XCTest
@testable import BorrowBuddy

@MainActor
final class LoanLifecycleTests: XCTestCase {
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
