import XCTest
@testable import BorrowBuddy

@MainActor
final class PerformanceTestingTests: XCTestCase {
    func testLargeNearbyCatalogLoadsAndSortsQuickly() async {
        let repository = InMemoryBorrowingRepository()
        repository.tools = (0..<1_000).map { index in
            CoverageFixtures.tool(
                id: "tool-\(index)",
                name: index.isMultiple(of: 2) ? "Drill \(index)" : "Ladder \(index)",
                latitude: 43.65 + (Double(index) * 0.0001),
                longitude: -79.38
            )
        }
        let model = NearbyMapViewModel()
        model.origin = CoverageFixtures.tool().coordinate
        model.showsAllLocations = true
        let started = Date()
        await model.load(using: repository)
        model.searchText = "drill"
        _ = model.filteredTools
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertEqual(model.filteredTools.count, 500)
        XCTAssertLessThanOrEqual(model.distance(to: model.filteredTools[0]) ?? 0, model.distance(to: model.filteredTools[499]) ?? 0)
    }

    func testLargeLoanCacheRoundTripStaysResponsive() {
        let store = OfflineCacheStore(inMemory: true)
        let loans = (0..<200).map { index in
            CoverageFixtures.loan(id: "loan-\(index)", returnAt: Date().addingTimeInterval(Double(index)))
        }
        let started = Date()
        store.saveLoans(loans)
        let loaded = store.loadLoans()
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
        XCTAssertEqual(loaded.count, 200)
        XCTAssertEqual(loaded.map(\.id), loans.map(\.id))
    }
}
