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
            XCTAssertEqual(country.flag.unicodeScalars.count, 2)
            XCTAssertFalse(country.flag.isEmpty)
            XCTAssertFalse(country.dialCode.isEmpty)
            XCTAssertGreaterThan(country.maxNationalDigits, 0)
            XCTAssertEqual(country.displayDialCode, "+\(country.dialCode)")
        }
    }

    func testThemeColorsStayStableAcrossAppearances() {
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let blue = CoverageFixtures.uiColor(AppTheme.blue, style: style)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blueChannel: CGFloat = 0
            var alpha: CGFloat = 0
            XCTAssertTrue(blue.getRed(&red, green: &green, blue: &blueChannel, alpha: &alpha))
            XCTAssertEqual(red, 0.22, accuracy: 0.02)
            XCTAssertEqual(green, 0.47, accuracy: 0.02)
            XCTAssertEqual(blueChannel, 0.62, accuracy: 0.02)
        }
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
