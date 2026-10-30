import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct UsabilityTestingTests {
    @Test func `Invalid forms explain what to fix`() async {
        let settings = AccountSettingsViewModel()
        let repository = InMemoryAccountRepository()
        let missingName = await settings.saveProfile(displayName: "", neighborhood: "Maple Grove", phoneNumber: "1", using: repository)
        #expect(!(missingName))
        #expect(settings.errorMessage == "Full name is required.")
        #expect(settings.successMessage == nil)

        let signUp = SignUpViewModel()
        signUp.fullName = "Jordan"
        signUp.email = "not-an-email"
        signUp.password = "secret1"
        #expect(!(signUp.canSubmit))
        let signedUp = await signUp.signUp(using: ScriptedAuthenticationService())
        #expect(!(signedUp))
        #expect(signUp.errorMessage == "Please enter a valid email address.")
    }

    @Test func `Successful save confirms the change`() async {
        let settings = AccountSettingsViewModel()
        let repository = InMemoryAccountRepository()
        let saved = await settings.saveProfile(displayName: "Jordan", neighborhood: "Maple Grove", phoneNumber: "+1 555 0100", using: repository)
        #expect(saved)
        #expect(settings.successMessage == "Profile saved.")
        #expect(settings.errorMessage == nil)

        settings.notifications.returnReminders = false
        let savedNotifications = await settings.saveNotifications(using: repository)
        #expect(savedNotifications)
        #expect(settings.successMessage == "Notification preferences saved.")
    }

    @Test func `Empty and failed loads use clear copy`() async {
        let model = NearbyMapViewModel()
        await model.load(using: InMemoryBorrowingRepository())
        #expect(model.emptyState == .noListings)
        #expect(model.resultSummary == "0 AVAILABLE TOOLS · ALL LOCATIONS")

        let offline = NearbyMapViewModel()
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.notConnectedToInternet)
        await offline.load(using: repository)
        #expect(offline.resultSummary == "UNABLE TO REFRESH AVAILABLE TOOLS")
        #expect(!(offline.errorMessage?.isEmpty ?? true))
    }

    @Test func `Verification feedback clears when the user edits`() {
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        #expect(verification.errorMessage == nil)
        #expect(verification.canVerify)
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        #expect(verification.errorMessage == nil)
        #expect(verification.canVerify)
    }
}
