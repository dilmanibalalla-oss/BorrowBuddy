import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct AuthorizationTestingTests {
    @Test func `Borrow limits follow role and verification`() {
        #expect(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 0, isPro: false))
        #expect(!(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 1, isPro: false)))
        #expect(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 3, isPro: true))
        #expect(!(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: true)))
        #expect(!(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: false)))
        #expect(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: true))
    }

    @Test func `Pickup is restricted to the borrower`() {
        let loan = CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true)
        #expect(PickupInspectionEligibility.blocker(for: loan, userID: "someone-else", kitConfirmed: true, wearReviewed: true) == .wrongAccount)
        #expect(PickupInspectionEligibility.blocker(for: loan, userID: nil, kitConfirmed: true, wearReviewed: true) == .wrongAccount)
        #expect(PickupInspectionEligibility.blocker(for: nil, userID: "borrower", kitConfirmed: true, wearReviewed: true) == .missingReservation)
        #expect(PickupInspectionEligibility.blocker(for: CoverageFixtures.loan(status: .pending, stage: .pending, ownerAccepted: false), userID: "borrower", kitConfirmed: true, wearReviewed: true) == .awaitingOwner)
        #expect(PickupInspectionEligibility.blocker(for: loan, userID: "borrower", kitConfirmed: false, wearReviewed: true) == .incompleteChecklist)
        #expect(PickupInspectionEligibility.blocker(for: loan, userID: "borrower", kitConfirmed: true, wearReviewed: true) == nil)
    }

    @Test func `Only the owner can open anon return case`() {
        let now = Date()
        let loan = CoverageFixtures.loan(returnAt: now.addingTimeInterval(-48 * 3600))
        #expect(LoanRules.canOpenNonReturnCase(loan, userID: loan.ownerID, now: now))
        #expect(!(LoanRules.canOpenNonReturnCase(loan, userID: loan.borrowerID, now: now)))
        #expect(!(LoanRules.canOpenNonReturnCase(loan, userID: loan.ownerID, now: loan.returnAt)))
        #expect(CommunityError.wrongRole.localizedDescription == "You can't borrow your own listing.")
        #expect(CommunityError.blocked.localizedDescription == "Borrowing is temporarily blocked on this account.")
    }

    @Test func `Owner and borrower see different loan screens`() {
        let inspection = CoverageFixtures.loan(status: .active, stage: .returnInspection)
        #expect(LoanScreenPresentation.screen(for: inspection, userID: inspection.borrowerID, baselineCount: 0) == .returnPhotos)
        #expect(LoanScreenPresentation.screen(for: inspection, userID: inspection.ownerID, baselineCount: 0) == .active)
    }
}
