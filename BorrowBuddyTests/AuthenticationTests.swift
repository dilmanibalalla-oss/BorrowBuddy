import XCTest
@testable import BorrowBuddy

@MainActor
final class AuthenticationTests: XCTestCase {
    func testLoginAcceptsTheLocalVerificationCode() {
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        let model = VerificationViewModel()
        model.updateCode("000000")
        XCTAssertEqual(model.errorMessage, "Incorrect verification code.")
        XCTAssertFalse(model.canVerify)
        model.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.canVerify)
    }
}
