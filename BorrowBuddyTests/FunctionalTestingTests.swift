import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct FunctionalTestingTests {
    @Test func `Form buttons enable only when input is ready`() {
        let signUp = SignUpViewModel()
        #expect(!(signUp.canSubmit))
        signUp.fullName = "Jordan Lee"
        signUp.email = "jordan@example.com"
        signUp.password = "secret"
        #expect(signUp.canSubmit)

        let login = LoginViewModel()
        #expect(!(login.canSubmit))
        login.email = "jordan@example.com"
        login.password = "secret"
        #expect(login.canSubmit)

        let phone = PhoneSignInViewModel()
        #expect(!(phone.canContinue))
        phone.format(DevAuthFixtures.testPhoneDigits)
        #expect(phone.canContinue)

        let verification = VerificationViewModel()
        #expect(!(verification.canVerify))
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        #expect(verification.canVerify)
    }

    @Test func `Tool listing supports create update and delete`() async throws {
        let repository = InMemoryBorrowingRepository()
        var drill = CoverageFixtures.tool(id: "drill", name: "Cordless Drill")
        let savedID = try await repository.addTool(drill)
        #expect(savedID == "drill")

        drill.listingStatus = "paused"
        try await repository.updateTool(drill)
        #expect(repository.tools.map(\.listingStatus) == ["paused"])

        let quote = ReservationQuote.make(for: drill, days: 2)
        let reservation = try await repository.createReservation(tool: drill, quote: quote)
        #expect(reservation.toolName == "Cordless Drill")
        let loans = try await repository.fetchMyLoans()
        #expect(loans.map(\.id) == [reservation.id])

        try await repository.deleteTool(id: "drill")
        #expect(repository.tools.isEmpty)
    }

    @Test func `Search filter and sort nearby tools`() async {
        let repository = InMemoryBorrowingRepository()
        repository.tools = [
            CoverageFixtures.tool(id: "far", name: "Ladder", category: "Access", latitude: 10, longitude: 10),
            CoverageFixtures.tool(id: "near", name: "Cordless Drill", category: "Power Tools", latitude: 43.6532, longitude: -79.3832),
            CoverageFixtures.tool(id: "mid", name: "Saw", category: "Power Tools", latitude: 44.2, longitude: -79.3832)
        ]
        let model = NearbyMapViewModel()
        await model.load(using: repository)

        model.searchText = "  drill "
        #expect(model.filteredTools.map(\.id) == ["near"])

        model.searchText = "power"
        model.origin = CoverageFixtures.tool().coordinate
        model.radiusKilometers = 5
        #expect(model.filteredTools.map(\.id) == ["near"])

        model.showsAllLocations = true
        #expect(model.filteredTools.map(\.id) == ["near", "mid"])
        #expect(model.resultSummary == "2 AVAILABLE TOOLS · ALL LOCATIONS")
    }

    @Test func `Ledger and schedule stay sorted`() async throws {
        let repository = DemoAccountRepository()
        let ledger = try await repository.loadLedger()
        #expect(ledger.map(\.recordedAt) == ledger.map(\.recordedAt).sorted(by: >))
        #expect(ConditionComparisonPolicy.verdict(for: 0.45) == .match)
        #expect(ConditionComparisonPolicy.verdict(for: 0.46) == .review)
    }
}
