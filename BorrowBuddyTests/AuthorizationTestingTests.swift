import XCTest
@testable import BorrowBuddy

@MainActor
final class AuthorizationTestingTests: XCTestCase {
    func testBorrowLimitsFollowRoleAndVerification() {
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 0, isPro: false))
        XCTAssertFalse(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 1, isPro: false))
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 3, isPro: true))
        XCTAssertFalse(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: true))
        XCTAssertFalse(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: false))
        XCTAssertTrue(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: true))
    }

    func testPickupIsRestrictedToTheBorrower() {
        let loan = CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true)
        XCTAssertEqual(PickupInspectionEligibility.blocker(for: loan, userID: "someone-else", kitConfirmed: true, wearReviewed: true), .wrongAccount)
        XCTAssertEqual(PickupInspectionEligibility.blocker(for: loan, userID: nil, kitConfirmed: true, wearReviewed: true), .wrongAccount)
        XCTAssertEqual(PickupInspectionEligibility.blocker(for: nil, userID: "borrower", kitConfirmed: true, wearReviewed: true), .missingReservation)
        XCTAssertEqual(
            PickupInspectionEligibility.blocker(for: CoverageFixtures.loan(status: .pending, stage: .pending, ownerAccepted: false), userID: "borrower", kitConfirmed: true, wearReviewed: true),
            .awaitingOwner
        )
        XCTAssertEqual(PickupInspectionEligibility.blocker(for: loan, userID: "borrower", kitConfirmed: false, wearReviewed: true), .incompleteChecklist)
        XCTAssertNil(PickupInspectionEligibility.blocker(for: loan, userID: "borrower", kitConfirmed: true, wearReviewed: true))
    }

    func testOnlyTheOwnerCanOpenANonReturnCase() {
        let now = Date()
        let loan = CoverageFixtures.loan(returnAt: now.addingTimeInterval(-48 * 3600))
        XCTAssertTrue(LoanRules.canOpenNonReturnCase(loan, userID: loan.ownerID, now: now))
        XCTAssertFalse(LoanRules.canOpenNonReturnCase(loan, userID: loan.borrowerID, now: now))
        XCTAssertFalse(LoanRules.canOpenNonReturnCase(loan, userID: loan.ownerID, now: loan.returnAt))
        XCTAssertEqual(CommunityError.wrongRole.localizedDescription, "You can't borrow your own listing.")
        XCTAssertEqual(CommunityError.blocked.localizedDescription, "Borrowing is temporarily blocked on this account.")
    }

    func testOwnerAndBorrowerSeeDifferentLoanScreens() {
        let inspection = CoverageFixtures.loan(status: .active, stage: .returnInspection)
        XCTAssertEqual(LoanScreenPresentation.screen(for: inspection, userID: inspection.borrowerID, baselineCount: 0), .returnPhotos)
        XCTAssertEqual(LoanScreenPresentation.screen(for: inspection, userID: inspection.ownerID, baselineCount: 0), .active)
    }
}
