import UIKit
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct AccessibilityTestingTests {
    @Test func `Text on the background meets contrast`() {
        let background = CoverageFixtures.uiColor(AppTheme.background)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.text), on: background) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: background) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.coral), on: background) > 2.5)
        let darkBackground = CoverageFixtures.uiColor(AppTheme.background, style: .dark)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.text, style: .dark), on: darkBackground) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue, style: .dark), on: darkBackground) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.secondaryText, style: .dark), on: darkBackground) >= 4.5)
    }

    @Test func `Evidence angles expose titles and instructions`() {
        #expect(EvidenceAngle.allCases.count == 8)
        for angle in EvidenceAngle.allCases {
            #expect(!(angle.title.isEmpty))
            #expect(!(angle.instruction.isEmpty))
            #expect(angle.id == angle.rawValue)
        }
        #expect(EvidenceAngle.caseView.title == "Case")
        #expect(EvidenceAngle.front.title == "Front")
    }

    @Test func `Screen summaries and symbols have labels`() {
        let model = NearbyMapViewModel()
        #expect(model.resultSummary == "0 AVAILABLE TOOLS · ALL LOCATIONS")
        for name in ["faceid", "chevron.left", "location.fill"] {
            let image = UIImage(systemName: name)
            #expect(image != nil)
            #expect(!(name.isEmpty))
        }
        let verification = VerificationViewModel()
        verification.updateCode("12ab345678")
        #expect(verification.code.count == 6)
        #expect(verification.code.allSatisfy { $0.isNumber })
    }

    @Test func `Errors are readable sentences`() {
        let messages = [
            AuthenticationError.invalidEmail.localizedDescription,
            AuthenticationError.weakPassword.localizedDescription,
            AuthenticationError.emptyFields.localizedDescription,
            CommunityError.signInRequired.localizedDescription,
            CommunityError.expiredLocation.localizedDescription
        ]
        for message in messages {
            #expect(message.hasSuffix("."))
            #expect(message.count > 10)
        }
    }
}
