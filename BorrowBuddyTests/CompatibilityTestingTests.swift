import UIKit
import Testing
@testable import BorrowBuddy

@MainActor
struct CompatibilityTestingTests {
    @Test func `Country catalog is sorted and has flags`() {
        let names = Country.all.map(\.name)
        #expect(names == names.sorted())
        #expect(Set(Country.all.map(\.id)).count == Country.all.count)
        #expect(Country.defaultCountry.id == "LK")
        for country in Country.all {
            #expect(country.flag.count == 1)
            #expect(!(country.flag.isEmpty))
            #expect(!(country.dialCode.isEmpty))
            #expect(country.maxNationalDigits > 0)
            #expect(country.displayDialCode == "+\(country.dialCode)")
        }
    }

    @Test func `Theme colors stay stable across appearances`() {
        let lightBlue = CoverageFixtures.uiColor(AppTheme.blue, style: .light)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blueChannel: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(lightBlue.getRed(&red, green: &green, blue: &blueChannel, alpha: &alpha))
        #expect(abs(red - 0.22) <= 0.02)
        #expect(abs(green - 0.47) <= 0.02)
        #expect(abs(blueChannel - 0.62) <= 0.02)

        let darkBlue = CoverageFixtures.uiColor(AppTheme.blue, style: .dark)
        let darkBackground = CoverageFixtures.uiColor(AppTheme.background, style: .dark)
        let darkText = CoverageFixtures.uiColor(AppTheme.text, style: .dark)
        #expect(CoverageFixtures.luminance(darkBlue) > CoverageFixtures.luminance(lightBlue))
        #expect(CoverageFixtures.contrast(darkText, on: darkBackground) >= 4.5)
        #expect(CoverageFixtures.contrast(darkBlue, on: darkBackground) >= 4.5)
        #expect(CoverageFixtures.contrast(CoverageFixtures.uiColor(AppTheme.onYellow, style: .dark), on: CoverageFixtures.uiColor(AppTheme.yellow, style: .dark)) >= 4.5)
    }

    @Test func `Local phone fixture accepts common formats`() {
        #expect(DevAuthFixtures.isTestPhone("713123411"))
        #expect(DevAuthFixtures.isTestPhone("+94 71 312 3411"))
        #expect(DevAuthFixtures.isTestPhone("+1 713 123 411"))
        #expect(!(DevAuthFixtures.isTestPhone("+1 555 0100")))
        #expect(DevAuthFixtures.isLocalVerificationID(DevAuthFixtures.localVerificationID))
        #expect(!(DevAuthFixtures.isLocalVerificationID(nil)))
    }

    @Test func `Biometry name is aknown platform value`() {
        let name = BiometricAuthService.shared.biometryTypeName
        #expect(["Face ID", "Touch ID", "Optic ID", "Biometrics"].contains(name))
    }
}
