import XCTest
@testable import BorrowBuddy

@MainActor
final class SecurityTestingTests: XCTestCase {
    func testPhoneAndCodeRejectInjectedText() {
        let phone = PhoneSignInViewModel()
        phone.format("'; DROP TABLE users; --")
        XCTAssertFalse(phone.phoneNumber.contains("DROP"))
        XCTAssertFalse(phone.phoneNumber.contains("'"))
        XCTAssertFalse(phone.canContinue)

        let verification = VerificationViewModel()
        verification.updateCode("<script>123456</script>")
        XCTAssertEqual(verification.code, "123456")
        XCTAssertFalse(verification.code.contains("<"))
    }

    func testRestrictedLoanActionsStayWithTheRightAccount() {
        let loan = CoverageFixtures.loan(returnAt: Date().addingTimeInterval(-48 * 3600))
        XCTAssertFalse(LoanRules.canOpenNonReturnCase(loan, userID: "intruder", now: Date()))
        XCTAssertFalse(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "intruder"))
        XCTAssertTrue(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: loan.borrowerID))
        XCTAssertEqual(
            PickupInspectionEligibility.blocker(
                for: CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true),
                userID: "intruder",
                kitConfirmed: true,
                wearReviewed: true
            ),
            .wrongAccount
        )
    }

    func testUnsignedSessionAndUnverifiedBorrowersAreBlocked() async {
        let service = ScriptedAuthenticationService()
        try? service.signOut()
        do {
            try await service.prepareAccount()
            XCTFail("A signed-out user should not prepare an account.")
        } catch {
            XCTAssertEqual(error.localizedDescription, AuthenticationError.signInRequired.localizedDescription)
        }
        XCTAssertFalse(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: false))
        XCTAssertNil(FirestoreModels.photoData(""))
        XCTAssertNil(FirestoreModels.photoData("not base64 !!!"))
    }

    func testDropOffRegionIdentifierIsTheLoanIdentifier() {
        let loan = CoverageFixtures.loan(id: "loan-42")
        let region = DropOffRegionPolicy.region(for: loan)
        XCTAssertEqual(region?.identifier, "loan-42")
        XCTAssertEqual(region?.radius, 50)
        XCTAssertFalse(region?.notifyOnExit ?? true)
    }
}
