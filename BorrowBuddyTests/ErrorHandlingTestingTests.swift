import UIKit
import XCTest
@testable import BorrowBuddy

@MainActor
final class ErrorHandlingTestingTests: XCTestCase {
    func testAuthenticationAndCommunityErrorsHaveMessages() {
        let authentication: [AuthenticationError] = [
            .invalidEmail, .weakPassword, .emptyFields, .invalidCode,
            .verificationNotStarted, .signInRequired, .biometricsUnavailable, .unknown
        ]
        for error in authentication {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        let community: [CommunityError] = [
            .signInRequired, .profileMissing, .unavailable, .invalidInput("Choose a smaller, clearer image."),
            .wrongRole, .blocked, .expiredLocation, .invalidStep
        ]
        for error in community {
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        XCTAssertFalse(ConditionComparisonError.unreadableImage.localizedDescription.isEmpty)
        XCTAssertFalse(ConditionComparisonError.featurePrintUnavailable.localizedDescription.isEmpty)
        XCTAssertEqual(BiometricError.cancelled.localizedDescription, "Face ID was cancelled.")
    }

    func testNetworkFailureWithoutACacheShowsTheError() async {
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.timedOut)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: OfflineCacheStore(inMemory: true))
        XCTAssertEqual(model.errorMessage, URLError(.timedOut).localizedDescription)
        XCTAssertTrue(model.filteredTools.isEmpty)
        XCTAssertNil(model.emptyState)
        XCTAssertEqual(model.resultSummary, "UNABLE TO REFRESH AVAILABLE TOOLS")
    }

    func testEmptySearchAndRadiusStates() async {
        let repository = InMemoryBorrowingRepository()
        let model = NearbyMapViewModel()
        await model.load(using: repository)
        XCTAssertEqual(model.emptyState, .noListings)

        repository.tools = [CoverageFixtures.tool(id: "far", name: "Ladder", latitude: 10, longitude: 10)]
        await model.load(using: repository)
        model.searchText = "drill"
        XCTAssertEqual(model.emptyState, .noSearchMatches)

        model.searchText = ""
        model.origin = CoverageFixtures.tool().coordinate
        model.radiusKilometers = 1
        XCTAssertEqual(model.emptyState, .outsideRadius)
    }

    func testUnreadablePhotoAndWrongCodeStayOnScreen() throws {
        XCTAssertThrowsError(try PhotoEncoding.jpeg(UIImage())) { error in
            XCTAssertEqual(error.localizedDescription, ConditionComparisonError.unreadableImage.localizedDescription)
        }
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        XCTAssertEqual(verification.errorMessage, "Incorrect verification code.")
        verification.updateCode("")
        XCTAssertNil(verification.errorMessage)
    }
}
