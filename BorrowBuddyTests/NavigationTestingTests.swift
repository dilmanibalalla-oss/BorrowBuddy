import XCTest
@testable import BorrowBuddy

@MainActor
final class NavigationTestingTests: XCTestCase {
    func testOnboardingTransitionsAndBackNavigation() {
        let router = AppRouter()
        XCTAssertEqual(router.route, .splash)
        router.go(to: .onboardingOne)
        router.go(to: .onboardingTwo)
        router.go(to: .signUp)
        router.go(to: .signIn)
        router.go(to: .verification)
        router.go(to: .signIn)
        XCTAssertEqual(router.route, .signIn)
        router.go(to: .verification)
        router.go(to: .faceID)
        router.go(to: .home)
        XCTAssertEqual(router.route, .home)
        router.go(to: .profile)
        router.go(to: .wallet)
        router.go(to: .home)
        XCTAssertEqual(router.route, .home)
    }

    func testAccountMenuDestinationsStayDistinct() {
        let menu: [AccountDestination] = [
            .editProfile, .notifications, .paymentMethods, .wallet,
            .creditTopUp, .loanProtection, .identityVerification
        ]
        XCTAssertEqual(Set(menu).count, menu.count)
    }

    func testLoanStageRedirectsByRole() {
        let borrowerLoan = CoverageFixtures.loan(status: .pending, stage: .pickupInspection, ownerAccepted: true)
        XCTAssertEqual(LoanScreenPresentation.screen(for: borrowerLoan, userID: "borrower", baselineCount: 0), .pickup)
        XCTAssertEqual(LoanScreenPresentation.screen(for: borrowerLoan, userID: "owner", baselineCount: 0), .pending)
        XCTAssertEqual(
            LoanScreenPresentation.screen(for: borrowerLoan, userID: "borrower", baselineCount: EvidenceAngle.allCases.count),
            .baseline
        )

        let returning = CoverageFixtures.loan(stage: .returnTransit)
        XCTAssertEqual(LoanScreenPresentation.screen(for: returning, userID: "borrower", baselineCount: 0), .returning)
        XCTAssertEqual(LoanScreenPresentation.screen(for: returning, userID: returning.ownerID, baselineCount: 0), .active)

        let completed = CoverageFixtures.loan(status: .completed, stage: .completed)
        XCTAssertEqual(LoanScreenPresentation.screen(for: completed, userID: "borrower", baselineCount: 0), .completed)
    }

    func testDropOffNotificationCarriesTheReservationLink() {
        let reservationID = "coverage-drop-off"
        let expectation = expectation(description: "drop-off link")
        let observer = NotificationCenter.default.addObserver(
            forName: .dropOffRegionEntered,
            object: nil,
            queue: .main
        ) { notification in
            guard notification.userInfo?["reservationID"] as? String == reservationID else { return }
            expectation.fulfill()
        }
        NotificationCenter.default.post(
            name: .dropOffRegionEntered,
            object: nil,
            userInfo: ["reservationID": reservationID]
        )
        wait(for: [expectation], timeout: 1)
        NotificationCenter.default.removeObserver(observer)
    }
}
