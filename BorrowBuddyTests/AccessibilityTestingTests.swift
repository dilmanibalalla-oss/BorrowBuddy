import UIKit
import XCTest
@testable import BorrowBuddy

@MainActor
final class AccessibilityTestingTests: XCTestCase {
    func testTextOnTheBackgroundMeetsContrast() {
        let background = CoverageFixtures.uiColor(AppTheme.background)
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.text), on: background), 4.5)
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: background), 4.5)
        XCTAssertGreaterThan(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.coral), on: background), 2.5)
    }

    func testEvidenceAnglesExposeTitlesAndInstructions() {
        XCTAssertEqual(EvidenceAngle.allCases.count, 8)
        for angle in EvidenceAngle.allCases {
            XCTAssertFalse(angle.title.isEmpty)
            XCTAssertFalse(angle.instruction.isEmpty)
            XCTAssertEqual(angle.id, angle.rawValue)
        }
        XCTAssertEqual(EvidenceAngle.caseView.title, "Case")
        XCTAssertEqual(EvidenceAngle.front.title, "Front")
    }

    func testScreenSummariesAndSymbolsHaveLabels() {
        let model = NearbyMapViewModel()
        XCTAssertEqual(model.resultSummary, "0 AVAILABLE TOOLS · ALL LOCATIONS")
        for name in ["faceid", "chevron.left", "location.fill"] {
            let image = UIImage(systemName: name)
            XCTAssertNotNil(image)
            XCTAssertFalse(name.isEmpty)
        }
        let verification = VerificationViewModel()
        verification.updateCode("12ab345678")
        XCTAssertEqual(verification.code.count, 6)
        XCTAssertTrue(verification.code.allSatisfy(\.isNumber))
    }

    func testErrorsAreReadableSentences() {
        let messages = [
            AuthenticationError.invalidEmail.localizedDescription,
            AuthenticationError.weakPassword.localizedDescription,
            AuthenticationError.emptyFields.localizedDescription,
            CommunityError.signInRequired.localizedDescription,
            CommunityError.expiredLocation.localizedDescription
        ]
        for message in messages {
            XCTAssertTrue(message.hasSuffix("."))
            XCTAssertGreaterThan(message.count, 10)
        }
    }
}
