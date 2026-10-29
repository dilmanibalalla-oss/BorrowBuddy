import XCTest
@testable import BorrowBuddy

@MainActor
final class FunctionalTestingTests: XCTestCase {
    func testFormButtonsEnableOnlyWhenInputIsReady() {
        let signUp = SignUpViewModel()
        XCTAssertFalse(signUp.canSubmit)
        signUp.fullName = "Jordan Lee"
        signUp.email = "jordan@example.com"
        signUp.password = "secret"
        XCTAssertTrue(signUp.canSubmit)

        let login = LoginViewModel()
        XCTAssertFalse(login.canSubmit)
        login.email = "jordan@example.com"
        login.password = "secret"
        XCTAssertTrue(login.canSubmit)

        let phone = PhoneSignInViewModel()
        XCTAssertFalse(phone.canContinue)
        phone.format(DevAuthFixtures.testPhoneDigits)
        XCTAssertTrue(phone.canContinue)

        let verification = VerificationViewModel()
        XCTAssertFalse(verification.canVerify)
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        XCTAssertTrue(verification.canVerify)
    }

    func testToolListingSupportsCreateUpdateAndDelete() async throws {
        let repository = InMemoryBorrowingRepository()
        var drill = CoverageFixtures.tool(id: "drill", name: "Cordless Drill")
        let savedID = try await repository.addTool(drill)
        XCTAssertEqual(savedID, "drill")

        drill.listingStatus = "paused"
        try await repository.updateTool(drill)
        XCTAssertEqual(repository.tools.map(\.listingStatus), ["paused"])

        let quote = ReservationQuote.make(for: drill, days: 2)
        let reservation = try await repository.createReservation(tool: drill, quote: quote)
        XCTAssertEqual(reservation.toolName, "Cordless Drill")
        let loans = try await repository.fetchMyLoans()
        XCTAssertEqual(loans.map(\.id), [reservation.id])

        try await repository.deleteTool(id: "drill")
        XCTAssertTrue(repository.tools.isEmpty)
    }

    func testSearchFilterAndSortNearbyTools() async {
        let repository = InMemoryBorrowingRepository()
        repository.tools = [
            CoverageFixtures.tool(id: "far", name: "Ladder", category: "Access", latitude: 10, longitude: 10),
            CoverageFixtures.tool(id: "near", name: "Cordless Drill", category: "Power Tools", latitude: 43.6532, longitude: -79.3832),
            CoverageFixtures.tool(id: "mid", name: "Saw", category: "Power Tools", latitude: 44.2, longitude: -79.3832)
        ]
        let model = NearbyMapViewModel()
        await model.load(using: repository)

        model.searchText = "  drill "
        XCTAssertEqual(model.filteredTools.map(\.id), ["near"])

        model.searchText = "power"
        model.origin = CoverageFixtures.tool().coordinate
        model.radiusKilometers = 5
        XCTAssertEqual(model.filteredTools.map(\.id), ["near"])

        model.showsAllLocations = true
        XCTAssertEqual(model.filteredTools.map(\.id), ["near", "mid"])
        XCTAssertEqual(model.resultSummary, "2 AVAILABLE TOOLS · ALL LOCATIONS")
    }

    func testLedgerAndScheduleStaySorted() async throws {
        let repository = DemoAccountRepository()
        let ledger = try await repository.loadLedger()
        XCTAssertEqual(ledger.map(\.recordedAt), ledger.map(\.recordedAt).sorted(by: >))
        XCTAssertEqual(ConditionComparisonPolicy.verdict(for: 0.45), .match)
        XCTAssertEqual(ConditionComparisonPolicy.verdict(for: 0.46), .review)
    }
}
