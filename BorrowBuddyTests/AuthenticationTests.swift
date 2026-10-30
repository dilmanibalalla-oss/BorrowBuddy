import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct AuthenticationTests {
    @Test func `Login accepts the local verification code`() {
        #expect(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let model = VerificationViewModel()
        model.updateCode("12345")
        #expect(!(model.canVerify))
        model.updateCode("000000")
        #expect(model.errorMessage == nil)
        #expect(model.canVerify)
        model.updateCode(DevAuthFixtures.testVerificationCode)
        #expect(model.errorMessage == nil)
        #expect(model.canVerify)
    }
}
