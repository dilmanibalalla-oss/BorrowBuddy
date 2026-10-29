import UIKit
import XCTest
@testable import BorrowBuddy

@MainActor
final class DatabaseTestingTests: XCTestCase {
    func testAccountSaveUpdateAndRetrieveStayConsistent() {
        let store = OfflineCacheStore(inMemory: true)
        XCTAssertNil(store.loadAccount())
        store.saveAccount(CoverageFixtures.account(name: "Jordan", balance: 42))
        store.saveAccount(CoverageFixtures.account(name: "Jordan Lee", balance: 70, identityVerified: true, isPro: true))
        let loaded = store.loadAccount()
        XCTAssertEqual(loaded?.displayName, "Jordan Lee")
        XCTAssertEqual(loaded?.creditBalance, 70)
        XCTAssertEqual(loaded?.identityVerified, true)
        XCTAssertEqual(loaded?.isPro, true)
    }

    func testToolAndLoanRecordsReplaceInsteadOfDuplicating() {
        let store = OfflineCacheStore(inMemory: true)
        store.saveTools([CoverageFixtures.tool(id: "drill"), CoverageFixtures.tool(id: "ladder", name: "Ladder")])
        store.saveTools([CoverageFixtures.tool(id: "saw", name: "Saw")])
        XCTAssertEqual(store.loadTools().map(\.id), ["saw"])

        let loan = CoverageFixtures.loan(id: "loan-1", status: .pending, stage: .pending)
        store.saveLoans([loan])
        var updated = loan
        updated.status = .active
        updated.lifecycleStage = .active
        store.saveLoans([updated])
        let loaded = store.loadLoans()
        XCTAssertEqual(loaded.map(\.id), ["loan-1"])
        XCTAssertEqual(loaded.first?.status, .active)
        XCTAssertEqual(loaded.first?.lifecycleStage, .active)
        XCTAssertEqual(loaded.first?.toolName, loan.toolName)
    }

    func testClearingACollectionRemovesTheSavedRows() {
        let store = OfflineCacheStore(inMemory: true)
        store.saveTools([.demo])
        store.saveLoans([CoverageFixtures.loan()])
        store.saveTools([])
        XCTAssertTrue(store.loadTools().isEmpty)
        XCTAssertEqual(store.loadLoans().map(\.id), ["loan-1"])
        store.saveLoans([])
        XCTAssertTrue(store.loadLoans().isEmpty)
    }

    func testEncodedPhotoStaysWithinTheStoredSizeLimit() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let data = try PhotoEncoding.jpeg(image)
        XCTAssertFalse(data.isEmpty)
        XCTAssertLessThanOrEqual(data.count, PhotoEncoding.maximumBytes)
        XCTAssertNotNil(UIImage(data: data))
    }
}
