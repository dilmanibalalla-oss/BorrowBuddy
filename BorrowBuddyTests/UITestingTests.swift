import SwiftUI
import UIKit
import XCTest
@testable import BorrowBuddy

@MainActor
final class UITestingTests: XCTestCase {
    func testThemeColorsMatchTheDesign() {
        assertComponents(AppTheme.blue, red: 0.22, green: 0.47, blue: 0.62)
        assertComponents(AppTheme.yellow, red: 1, green: 0.81, blue: 0.23)
        assertComponents(AppTheme.green, red: 0.37, green: 0.51, blue: 0.43)
        assertComponents(AppTheme.coral, red: 0.88, green: 0.45, blue: 0.36)
        assertComponents(AppTheme.background, red: 0.99, green: 0.99, blue: 0.98)
        assertComponents(AppTheme.text, red: 0.18, green: 0.18, blue: 0.19)
    }

    func testTextAndBrandColorsStayReadable() {
        let background = CoverageFixtures.uiColor(AppTheme.background)
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.text), on: background), 4.5)
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: background), 4.5)
        XCTAssertGreaterThan(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: CoverageFixtures.uiColor(AppTheme.yellow)), 2.5)
    }

    func testRoundedFontsAndIconsAreAvailable() {
        let sizes: [CGFloat] = [11, 13, 15, 16, 20, 28, 34]
        for size in sizes {
            _ = AppTheme.rounded(size, weight: .heavy)
            _ = AppTheme.rounded(size, weight: .bold)
            _ = AppTheme.rounded(size, weight: .regular)
        }
        for name in ["faceid", "wrench.adjustable", "chevron.left", "location.fill", "mappin.circle.fill"] {
            XCTAssertNotNil(UIImage(systemName: name), name)
        }
    }

    func testPrimaryButtonKeepsHeightAndWidth() {
        let size = CoverageFixtures.renderedSize(width: 320)
        XCTAssertEqual(size.width, 320, accuracy: 1)
        XCTAssertGreaterThanOrEqual(size.height, 48)
        XCTAssertLessThanOrEqual(size.height, 80)
    }

    private func assertComponents(_ color: Color, red: CGFloat, green: CGFloat, blue: CGFloat) {
        let resolved = CoverageFixtures.uiColor(color)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &alpha))
        XCTAssertEqual(actualRed, red, accuracy: 0.02)
        XCTAssertEqual(actualGreen, green, accuracy: 0.02)
        XCTAssertEqual(actualBlue, blue, accuracy: 0.02)
        XCTAssertEqual(alpha, 1, accuracy: 0.01)
    }
}
