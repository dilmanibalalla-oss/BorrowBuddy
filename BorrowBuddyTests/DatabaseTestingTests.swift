import UIKit
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct DatabaseTestingTests {
    @Test func `Account save update and retrieve stay consistent`() {
        let store = OfflineCacheStore(inMemory: true)
        #expect(store.loadAccount() == nil)
        store.saveAccount(CoverageFixtures.account(name: "Jordan", balance: 42))
        store.saveAccount(CoverageFixtures.account(name: "Jordan Lee", balance: 70, identityVerified: true, isPro: true))
        let loaded = store.loadAccount()
        #expect(loaded?.displayName == "Jordan Lee")
        #expect(loaded?.creditBalance == 70)
        #expect(loaded?.identityVerified == true)
        #expect(loaded?.isPro == true)
    }

    @Test func `Tool and loan records replace instead of duplicating`() {
        let store = OfflineCacheStore(inMemory: true)
        store.saveTools([CoverageFixtures.tool(id: "drill"), CoverageFixtures.tool(id: "ladder", name: "Ladder")])
        store.saveTools([CoverageFixtures.tool(id: "saw", name: "Saw")])
        #expect(store.loadTools().map(\.id) == ["saw"])

        let loan = CoverageFixtures.loan(id: "loan-1", status: .pending, stage: .pending)
        store.saveLoans([loan])
        var updated = loan
        updated.status = .active
        updated.lifecycleStage = .active
        store.saveLoans([updated])
        let loaded = store.loadLoans()
        #expect(loaded.map(\.id) == ["loan-1"])
        #expect(loaded.first?.status == .active)
        #expect(loaded.first?.lifecycleStage == .active)
        #expect(loaded.first?.toolName == loan.toolName)
    }

    @Test func `Clearing acollection removes the saved rows`() {
        let store = OfflineCacheStore(inMemory: true)
        store.saveTools([.demo])
        store.saveLoans([CoverageFixtures.loan()])
        store.saveTools([])
        #expect(store.loadTools().isEmpty)
        #expect(store.loadLoans().map(\.id) == ["loan-1"])
        store.saveLoans([])
        #expect(store.loadLoans().isEmpty)
    }

    @Test func `Encoded photo stays within the stored size limit`() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let data = try PhotoEncoding.jpeg(image)
        #expect(!(data.isEmpty))
        #expect(data.count <= PhotoEncoding.maximumBytes)
        #expect(UIImage(data: data) != nil)
    }
}
