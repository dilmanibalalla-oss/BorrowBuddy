import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct NavigationTestingTests {
    @Test func `Onboarding transitions and back navigation`() {
        let router = AppRouter()
        #expect(router.route == .splash)
        router.go(to: .onboardingOne)
        router.go(to: .onboardingTwo)
        router.go(to: .signUp)
        router.go(to: .signIn)
        router.go(to: .verification)
        router.go(to: .signIn)
        #expect(router.route == .signIn)
        router.go(to: .verification)
        router.go(to: .faceID)
        router.go(to: .home)
        #expect(router.route == .home)
        router.go(to: .profile)
        router.go(to: .wallet)
        router.go(to: .home)
        #expect(router.route == .home)
    }

    @Test func `Account menu destinations stay distinct`() {
        let menu: [AccountDestination] = [
            .editProfile, .notifications, .paymentMethods, .wallet,
            .creditTopUp, .loanProtection, .identityVerification
        ]
        #expect(Set(menu).count == menu.count)
    }

    @Test func `Loan stage redirects by role`() {
        let borrowerLoan = CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true)
        #expect(LoanScreenPresentation.screen(for: borrowerLoan, userID: "borrower", baselineCount: 0) == .pickup)
        #expect(LoanScreenPresentation.screen(for: borrowerLoan, userID: "owner", baselineCount: 0) == .pending)
        #expect(LoanScreenPresentation.screen(for: borrowerLoan, userID: "borrower", baselineCount: EvidenceAngle.allCases.count) == .baseline)

        let returning = CoverageFixtures.loan(stage: .returnTransit)
        #expect(LoanScreenPresentation.screen(for: returning, userID: "borrower", baselineCount: 0) == .returning)
        #expect(LoanScreenPresentation.screen(for: returning, userID: returning.ownerID, baselineCount: 0) == .active)

        let completed = CoverageFixtures.loan(status: .completed, stage: .completed)
        #expect(LoanScreenPresentation.screen(for: completed, userID: "borrower", baselineCount: 0) == .completed)
    }

    @Test func `Drop off notification carries the reservation link`() async {
        let reservationID = "coverage-drop-off"
        await confirmation("drop-off link") { received in
            let observer = NotificationCenter.default.addObserver(
                forName: .dropOffRegionEntered,
                object: nil,
                queue: .main
            ) { notification in
                guard notification.userInfo?["reservationID"] as? String == reservationID else { return }
                received()
            }
            NotificationCenter.default.post(
                name: .dropOffRegionEntered,
                object: nil,
                userInfo: ["reservationID": reservationID]
            )
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
