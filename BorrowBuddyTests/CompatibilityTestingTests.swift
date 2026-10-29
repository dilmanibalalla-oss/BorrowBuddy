import XCTest
@testable import BorrowBuddy

@MainActor
final class CompatibilityTestingTests: XCTestCase {
    func testCountryCatalogIsSortedAndHasFlags() {
        let names = Country.all.map(\.name)
        XCTAssertEqual(names, names.sorted())
        XCTAssertEqual(Set(Country.all.map(\.id)).count, Country.all.count)
        XCTAssertEqual(Country.defaultCountry.id, "LK")
        for country in Country.all {
            XCTAssertEqual(country.flag.count, 1)
            XCTAssertFalse(country.flag.isEmpty)
            XCTAssertFalse(country.dialCode.isEmpty)
            XCTAssertGreaterThan(country.maxNationalDigits, 0)
            XCTAssertEqual(country.displayDialCode, "+\(country.dialCode)")
        }
    }

    func testThemeColorsStayStableAcrossAppearances() {
        let lightBlue = CoverageFixtures.uiColor(AppTheme.blue, style: .light)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blueChannel: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(lightBlue.getRed(&red, green: &green, blue: &blueChannel, alpha: &alpha))
        XCTAssertEqual(red, 0.22, accuracy: 0.02)
        XCTAssertEqual(green, 0.47, accuracy: 0.02)
        XCTAssertEqual(blueChannel, 0.62, accuracy: 0.02)

        let darkBlue = CoverageFixtures.uiColor(AppTheme.blue, style: .dark)
        let darkBackground = CoverageFixtures.uiColor(AppTheme.background, style: .dark)
        let darkText = CoverageFixtures.uiColor(AppTheme.text, style: .dark)
        XCTAssertGreaterThan(CoverageFixtures.luminance(darkBlue), CoverageFixtures.luminance(lightBlue))
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(darkText, on: darkBackground), 4.5)
        XCTAssertGreaterThanOrEqual(CoverageFixtures.contrast(darkBlue, on: darkBackground), 4.5)
        XCTAssertGreaterThanOrEqual(
            CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.onYellow, style: .dark), on: CoverageFixtures.uiColor(AppTheme.yellow, style: .dark)),
            4.5
        )
    }

    func testLocalPhoneFixtureAcceptsCommonFormats() {
        XCTAssertTrue(DevAuthFixtures.isTestPhone("713123411"))
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+94 71 312 3411"))
        XCTAssertTrue(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        XCTAssertFalse(DevAuthFixtures.isTestPhone("+1 555 0100"))
        XCTAssertTrue(DevAuthFixtures.isLocalVerificationID(DevAuthFixtures.localVerificationID))
        XCTAssertFalse(DevAuthFixtures.isLocalVerificationID(nil))
    }

    func testBiometryNameIsAKnownPlatformValue() {
        let name = BiometricAuthService.shared.biometryTypeName
        XCTAssertTrue(["Face ID", "Touch ID", "Optic ID", "Biometrics"].contains(name))
    }
}
