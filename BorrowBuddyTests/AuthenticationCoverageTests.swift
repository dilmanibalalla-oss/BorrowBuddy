import XCTest
@testable import BorrowBuddy

@MainActor
final class AuthenticationCoverageTests: XCTestCase {
    func testRegistrationAcceptsAValidAccount() async {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let model = SignUpViewModel()
        model.fullName = " Jordan Lee "
        model.email = "Jordan@Example.com"
        model.password = "secret1"
        let signedUp = await model.signUp(using: service)
        XCTAssertTrue(signedUp)
        XCTAssertEqual(service.currentDisplayName, "Jordan Lee")
        XCTAssertEqual(service.signedInEmail, "jordan@example.com")
        XCTAssertNil(model.errorMessage)
    }

    func testLoginLogoutAndEndedSession() async throws {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let login = LoginViewModel()
        login.email = " Jordan@Example.com "
        login.password = "secret1"
        let signedIn = await login.signIn(using: service)
        XCTAssertTrue(signedIn)
        XCTAssertEqual(service.signedInEmail, "jordan@example.com")

        try service.signOut()
        XCTAssertNil(service.currentUserID)
        XCTAssertNil(service.currentDisplayName)
        var states: [Bool] = []
        for await signedIn in service.authenticationStateChanges() {
            states.append(signedIn)
        }
        XCTAssertEqual(states, [false])

        do {
            try await service.completeOnboarding()
            XCTFail("A signed-out session should not continue.")
        } catch {
            XCTAssertEqual(error.localizedDescription, CommunityError.signInRequired.localizedDescription)
        }
    }

    func testLocalVerificationAndWrongCode() async {
        let service = ScriptedAuthenticationService()
        let phone = PhoneSignInViewModel()
        phone.format(DevAuthFixtures.testPhoneDigits)
        let verificationID = await phone.sendCode(using: service)
        XCTAssertEqual(verificationID, DevAuthFixtures.localVerificationID)

        let verification = VerificationViewModel()
        verification.updateCode("000000")
        let rejected = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        XCTAssertFalse(rejected)
        XCTAssertEqual(verification.errorMessage, "Incorrect verification code.")

        verification.updateCode(DevAuthFixtures.testVerificationCode)
        let verified = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        XCTAssertTrue(verified)
    }

    func testFailedLoginShowsTheServiceMessage() async {
        let service = ScriptedAuthenticationService()
        service.signInError = NSError(domain: "FIRAuth", code: 17009, userInfo: [NSLocalizedDescriptionKey: "bad"])
        let login = LoginViewModel()
        login.email = "jordan@example.com"
        login.password = "wrong-password"
        let signedIn = await login.signIn(using: service)
        XCTAssertFalse(signedIn)
        XCTAssertEqual(login.errorMessage, "Incorrect email or password.")
    }
}
