import XCTest
@testable import BorrowBuddy

@MainActor
final class AuthenticationTests: XCTestCase {
    func testLoginAcceptsTheLocalVerificationCode() {
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let model = VerificationViewModel()
        model.updateCode("12345")
        XCTAssertFalse(model.canVerify)
        model.updateCode("000000")
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.canVerify)
        model.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.canVerify)
    }
}
