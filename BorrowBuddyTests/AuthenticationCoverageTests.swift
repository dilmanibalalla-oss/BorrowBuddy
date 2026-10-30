import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct AuthenticationCoverageTests {
    @Test func `Registration accepts avalid account`() async {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let model = SignUpViewModel()
        model.fullName = " Jordan Lee "
        model.email = "Jordan@Example.com"
        model.password = "secret1"
        let signedUp = await model.signUp(using: service)
        #expect(signedUp)
        #expect(service.currentDisplayName == "Jordan Lee")
        #expect(service.signedInEmail == "jordan@example.com")
        #expect(model.errorMessage == nil)
    }

    @Test func `Login logout and ended session`() async throws {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let login = LoginViewModel()
        login.email = " Jordan@Example.com "
        login.password = "secret1"
        let signedIn = await login.signIn(using: service)
        #expect(signedIn)
        #expect(service.signedInEmail == "jordan@example.com")

        try service.signOut()
        #expect(service.currentUserID == nil)
        #expect(service.currentDisplayName == nil)
        var states: [Bool] = []
        for await signedIn in service.authenticationStateChanges() {
            states.append(signedIn)
        }
        #expect(states == [false])

        do {
            try await service.completeOnboarding()
            Issue.record("A signed-out session should not continue.")
        } catch {
            #expect(error.localizedDescription == CommunityError.signInRequired.localizedDescription)
        }
    }

    @Test func `Local verification and wrong code`() async {
        let service = ScriptedAuthenticationService()
        let phone = PhoneSignInViewModel()
        phone.format(DevAuthFixtures.testPhoneDigits)
        let verificationID = await phone.sendCode(using: service)
        #expect(verificationID == DevAuthFixtures.localVerificationID)

        let verification = VerificationViewModel()
        verification.updateCode("000000")
        let rejected = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        #expect(!(rejected))
        #expect(verification.errorMessage == "Incorrect verification code.")

        verification.updateCode(DevAuthFixtures.testVerificationCode)
        let verified = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        #expect(verified)
    }

    @Test func `Failed login shows the service message`() async {
        let service = ScriptedAuthenticationService()
        service.signInError = NSError(domain: "FIRAuth", code: 17009, userInfo: [NSLocalizedDescriptionKey: "bad"])
        let login = LoginViewModel()
        login.email = "jordan@example.com"
        login.password = "wrong-password"
        let signedIn = await login.signIn(using: service)
        #expect(!(signedIn))
        #expect(login.errorMessage == "Incorrect email or password.")
    }
}
