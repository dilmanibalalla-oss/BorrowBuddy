import XCTest
@testable import BorrowBuddy

@MainActor
final class AccountTests: XCTestCase {
    func testCreditBalanceMath() {
        let quote = ReservationQuote.make(for: .demo, days: 2)
        XCTAssertEqual(quote.totalHold, quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
        XCTAssertEqual(LendCreditMath.balance(afterHold: quote.totalHold, current: 100), 100 - quote.totalHold)
        XCTAssertNil(LendCreditMath.balance(afterHold: 40, current: 10))
        XCTAssertEqual(LendCreditMath.balance(afterPurchase: CreditPack.builder.credits, current: 20), 170)
        let settlement = LoanSettlement(totalHold: 30, loanCharge: 18, depositRefund: 12)
        XCTAssertEqual(settlement.balanceChange, 12)
    }

    func testStoreKitCatalogAndProRules() {
        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.starterProductID), 50)
        XCTAssertEqual(StoreCatalog.credits(for: StoreCatalog.builderProductID), 150)
        XCTAssertNil(StoreCatalog.credits(for: StoreCatalog.proMonthlyProductID))
        XCTAssertEqual(CreditPack.starter.productID, StoreCatalog.starterProductID)
        XCTAssertEqual(MembershipPolicy.proWelcomeCredits, 10)
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 0, isPro: false))
        XCTAssertFalse(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 1, isPro: false))
        XCTAssertTrue(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 3, isPro: true))
        XCTAssertFalse(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: true))
        XCTAssertTrue(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: true))
    }
}
