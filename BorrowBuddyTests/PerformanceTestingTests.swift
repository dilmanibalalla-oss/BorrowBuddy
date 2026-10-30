import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct PerformanceTestingTests {
    @Test func `Large nearby catalog loads and sorts quickly`() async {
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
        #expect(Date().timeIntervalSince(started) < 2)
        #expect(model.filteredTools.count == 500)
        #expect(model.distance(to: model.filteredTools[0]) ?? 0 <= model.distance(to: model.filteredTools[499]) ?? 0)
    }

    @Test func `Large loan cache round trip stays responsive`() {
        let store = OfflineCacheStore(inMemory: true)
        let loans = (0..<200).map { index in
            CoverageFixtures.loan(id: "loan-\(index)", returnAt: Date().addingTimeInterval(Double(index)))
        }
        let started = Date()
        store.saveLoans(loans)
        let loaded = store.loadLoans()
        #expect(Date().timeIntervalSince(started) < 2)
        #expect(loaded.count == 200)
        #expect(loaded.map(\.id) == loans.map(\.id))
    }
}
