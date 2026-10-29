import XCTest
@testable import BorrowBuddy

@MainActor
final class ResponsiveTestingTests: XCTestCase {
    func testMapZoomClampsOnPhoneAndWideLayouts() {
        XCTAssertEqual(MapZoomPolicy.distance(from: 100, zoomingIn: true), 100)
        XCTAssertEqual(MapZoomPolicy.distance(from: 20_000_000, zoomingIn: false), 20_000_000)
        XCTAssertEqual(MapZoomPolicy.distance(from: 1_000, zoomingIn: true), 500)
        XCTAssertEqual(MapZoomPolicy.distance(from: 1_000, zoomingIn: false), 2_000)
        XCTAssertEqual(MapZoomPolicy.distance(from: .infinity, zoomingIn: true), 2_500)
        XCTAssertEqual(MapZoomPolicy.distance(from: 0, zoomingIn: false), 10_000)
    }

    func testPrimaryButtonFitsPhoneTabletAndDesktopWidths() {
        for width in [320.0, 390.0, 768.0, 1024.0] {
            let size = CoverageFixtures.renderedSize(width: width)
            XCTAssertEqual(size.width, width, accuracy: 1, "width \(width)")
            XCTAssertGreaterThanOrEqual(size.height, 48, "width \(width)")
        }
    }

    func testPhoneFieldsFollowEachCountryLength() {
        let phone = PhoneSignInViewModel()
        let singapore = Country.all.first { $0.id == "SG" }
        let germany = Country.all.first { $0.id == "DE" }
        phone.selectCountry(singapore!)
        phone.format(String(repeating: "7", count: 20))
        XCTAssertEqual(phone.phoneNumber.filter(\.isNumber).count, 8)
        phone.selectCountry(germany!)
        phone.format(String(repeating: "1", count: 20))
        XCTAssertEqual(phone.phoneNumber.filter(\.isNumber).count, 11)
    }
}
