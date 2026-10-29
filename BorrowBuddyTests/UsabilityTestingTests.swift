import XCTest
@testable import BorrowBuddy

@MainActor
final class UsabilityTestingTests: XCTestCase {
    func testInvalidFormsExplainWhatToFix() async {
        let settings = AccountSettingsViewModel()
        let repository = InMemoryAccountRepository()
        let missingName = await settings.saveProfile(displayName: "", neighborhood: "Maple Grove", phoneNumber: "1", using: repository)
        XCTAssertFalse(missingName)
        XCTAssertEqual(settings.errorMessage, "Full name is required.")
        XCTAssertNil(settings.successMessage)

        let signUp = SignUpViewModel()
        signUp.fullName = "Jordan"
        signUp.email = "not-an-email"
        signUp.password = "secret1"
        XCTAssertFalse(signUp.canSubmit)
        let signedUp = await signUp.signUp(using: ScriptedAuthenticationService())
        XCTAssertFalse(signedUp)
        XCTAssertEqual(signUp.errorMessage, "Please enter a valid email address.")
    }

    func testSuccessfulSaveConfirmsTheChange() async {
        let settings = AccountSettingsViewModel()
        let repository = InMemoryAccountRepository()
        let saved = await settings.saveProfile(displayName: "Jordan", neighborhood: "Maple Grove", phoneNumber: "+1 555 0100", using: repository)
        XCTAssertTrue(saved)
        XCTAssertEqual(settings.successMessage, "Profile saved.")
        XCTAssertNil(settings.errorMessage)

        settings.notifications.returnReminders = false
        let savedNotifications = await settings.saveNotifications(using: repository)
        XCTAssertTrue(savedNotifications)
        XCTAssertEqual(settings.successMessage, "Notification preferences saved.")
    }

    func testEmptyAndFailedLoadsUseClearCopy() async {
        let model = NearbyMapViewModel()
        await model.load(using: InMemoryBorrowingRepository())
        XCTAssertEqual(model.emptyState, .noListings)
        XCTAssertEqual(model.resultSummary, "0 AVAILABLE TOOLS · ALL LOCATIONS")

        let offline = NearbyMapViewModel()
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.notConnectedToInternet)
        await offline.load(using: repository)
        XCTAssertEqual(offline.resultSummary, "UNABLE TO REFRESH AVAILABLE TOOLS")
        XCTAssertFalse(offline.errorMessage?.isEmpty ?? true)
    }

    func testVerificationFeedbackClearsWhenTheUserEdits() {
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        XCTAssertEqual(verification.errorMessage, "Incorrect verification code.")
        XCTAssertFalse(verification.canVerify)
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertNil(verification.errorMessage)
        XCTAssertTrue(verification.canVerify)
    }
}
