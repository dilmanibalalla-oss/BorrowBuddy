import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct ResponsiveTestingTests {
    @Test func `Map zoom clamps on phone and wide layouts`() {
        #expect(MapZoomPolicy.distance(from: 100, zoomingIn: true) == 100)
        #expect(MapZoomPolicy.distance(from: 20_000_000, zoomingIn: false) == 20_000_000)
        #expect(MapZoomPolicy.distance(from: 1_000, zoomingIn: true) == 500)
        #expect(MapZoomPolicy.distance(from: 1_000, zoomingIn: false) == 2_000)
        #expect(MapZoomPolicy.distance(from: .infinity, zoomingIn: true) == 2_500)
        #expect(MapZoomPolicy.distance(from: 0, zoomingIn: false) == 10_000)
    }

    @Test func `Primary button fits phone tablet and desktop widths`() {
        for width in [320.0, 390.0, 768.0, 1024.0] {
            let size = CoverageFixtures.renderedSize(width: width)
            #expect(abs(size.width - width) <= 1, "width \(width)")
            #expect(size.height >= 48, "width \(width)")
        }
    }

    @Test func `Phone fields follow each country length`() {
        let phone = PhoneSignInViewModel()
        let singapore = Country.all.first { $0.id == "SG" }
        let germany = Country.all.first { $0.id == "DE" }
        phone.selectCountry(singapore!)
        phone.format(String(repeating: "7", count: 20))
        #expect(phone.phoneNumber.filter(\.isNumber).count == 8)
        phone.selectCountry(germany!)
        phone.format(String(repeating: "1", count: 20))
        #expect(phone.phoneNumber.filter(\.isNumber).count == 11)
    }
}
