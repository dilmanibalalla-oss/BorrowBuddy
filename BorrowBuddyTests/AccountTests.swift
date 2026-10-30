import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct AccountTests {
    @Test func `Credit balance math`() {
        let quote = ReservationQuote.make(for: .demo, days: 2)
        #expect(quote.totalHold == quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
        #expect(LendCreditMath.balance(afterHold: quote.totalHold, current: 100) == 100 - quote.totalHold)
        #expect(LendCreditMath.balance(afterHold: 40, current: 10) == nil)
        #expect(LendCreditMath.balance(afterPurchase: CreditPack.builder.credits, current: 20) == 170)
        let settlement = LoanSettlement(totalHold: 30, loanCharge: 18, depositRefund: 12)
        #expect(settlement.balanceChange == 12)
    }

    @Test func `Store kit catalog and pro rules`() {
        #expect(StoreCatalog.credits(for: StoreCatalog.starterProductID) == 50)
        #expect(StoreCatalog.credits(for: StoreCatalog.builderProductID) == 150)
        #expect(StoreCatalog.credits(for: StoreCatalog.proMonthlyProductID) == nil)
        #expect(CreditPack.starter.productID == StoreCatalog.starterProductID)
        #expect(MembershipPolicy.proWelcomeCredits == 10)
        #expect(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 0, isPro: false))
        #expect(!(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 1, isPro: false)))
        #expect(MembershipPolicy.canStartAnotherBorrow(openBorrowCount: 3, isPro: true))
        #expect(!(MembershipPolicy.canBorrowHighValueTool(identityVerified: false, addressConfirmed: true)))
        #expect(MembershipPolicy.canBorrowHighValueTool(identityVerified: true, addressConfirmed: true))
    }
}
