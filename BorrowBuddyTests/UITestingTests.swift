import SwiftUI
import UIKit
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct UITestingTests {
    @Test func `Theme colors match the design`() {
        assertComponents(AppTheme.blue, red: 0.22, green: 0.47, blue: 0.62)
        assertComponents(AppTheme.yellow, red: 1, green: 0.81, blue: 0.23)
        assertComponents(AppTheme.green, red: 0.37, green: 0.51, blue: 0.43)
        assertComponents(AppTheme.coral, red: 0.88, green: 0.45, blue: 0.36)
        assertComponents(AppTheme.background, red: 0.99, green: 0.99, blue: 0.98)
        assertComponents(AppTheme.text, red: 0.18, green: 0.18, blue: 0.19)
    }

    @Test func `Text and brand colors stay readable`() {
        let background = CoverageFixtures.uiColor(AppTheme.background)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.text), on: background) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: background) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.blue), on: CoverageFixtures.uiColor(AppTheme.yellow)) > 2.5)
    }

    @Test func `Rounded fonts and icons are available`() {
        let sizes: [CGFloat] = [11, 13, 15, 16, 20, 28, 34]
        for size in sizes {
            _ = AppTheme.rounded(size, weight: .heavy)
            _ = AppTheme.rounded(size, weight: .bold)
            _ = AppTheme.rounded(size, weight: .regular)
        }
        for name in ["faceid", "wrench.adjustable", "chevron.left", "location.fill", "mappin.circle.fill"] {
            #expect(UIImage(systemName: name) != nil, Comment(rawValue: name))
        }
    }

    @Test func `Primary button keeps height and width`() {
        let size = CoverageFixtures.renderedSize(width: 320)
        #expect(abs(size.width - 320) <= 1)
        #expect(size.height >= 48)
        #expect(size.height <= 80)
    }

    private func assertComponents(_ color: Color, red: CGFloat, green: CGFloat, blue: CGFloat) {
        let resolved = CoverageFixtures.uiColor(color)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(resolved.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &alpha))
        #expect(abs(actualRed - red) <= 0.02)
        #expect(abs(actualGreen - green) <= 0.02)
        #expect(abs(actualBlue - blue) <= 0.02)
        #expect(abs(alpha - 1) <= 0.01)
    }
}
