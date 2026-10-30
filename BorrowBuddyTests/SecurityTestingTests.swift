import CoreLocation
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct SecurityTestingTests {
    @Test func `Phone and code reject injected text`() {
        let phone = PhoneSignInViewModel()
        phone.format("'; DROP TABLE users; --")
        #expect(!(phone.phoneNumber.contains("DROP")))
        #expect(!(phone.phoneNumber.contains("'")))
        #expect(!(phone.canContinue))

        let verification = VerificationViewModel()
        verification.updateCode("<script>123456</script>")
        #expect(verification.code == "123456")
        #expect(!(verification.code.contains("<")))
    }

    @Test func `Restricted loan actions stay with the right account`() {
        let loan = CoverageFixtures.loan(returnAt: Date().addingTimeInterval(-48 * 3600))
        #expect(!(LoanRules.canOpenNonReturnCase(loan, userID: "intruder", now: Date())))
        #expect(!(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: "intruder")))
        #expect(DropOffRegionPolicy.shouldMonitor(loan, borrowerID: loan.borrowerID))
        #expect(PickupInspectionEligibility.blocker(
                for: CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true),
                userID: "intruder",
                kitConfirmed: true,
                wearReviewed: true
            ) == .wrongAccount)
    }

    @Test func `Unsigned session and unverified borrowers are blocked`() async {
        let service = ScriptedAuthenticationService()
        try? service.signOut()
        do {
            try await service.prepareAccount()
            Issue.record("A signed-out user should not prepare an account.")
        } catch {
            #expect(error.localizedDescription == AuthenticationError.signInRequired.localizedDescription)
        }
        #expect(!(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: false)))
        #expect(FirestoreModels.photoData("") == nil)
        #expect(FirestoreModels.photoData("not base64 !!!") == nil)
    }

    @Test func `Drop off region identifier is the loan identifier`() {
        let loan = CoverageFixtures.loan(id: "loan-42")
        let region = DropOffRegionPolicy.region(for: loan)
        #expect(region?.identifier == "loan-42")
        #expect(region?.radius == 50)
        #expect(!(region?.notifyOnExit ?? true))
    }
}
