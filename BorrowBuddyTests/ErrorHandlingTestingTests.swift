import UIKit
import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct ErrorHandlingTestingTests {
    @Test func `Authentication and community errors have messages`() {
        let authentication: [AuthenticationError] = [
            .invalidEmail, .weakPassword, .emptyFields, .invalidCode,
            .verificationNotStarted, .signInRequired, .biometricsUnavailable, .unknown
        ]
        for error in authentication {
            #expect(!(error.localizedDescription.isEmpty))
        }
        let community: [CommunityError] = [
            .signInRequired, .profileMissing, .unavailable, .invalidInput("Choose a smaller, clearer image."),
            .wrongRole, .blocked, .expiredLocation, .invalidStep
        ]
        for error in community {
            #expect(!(error.localizedDescription.isEmpty))
        }
        #expect(!(ConditionComparisonError.unreadableImage.localizedDescription.isEmpty))
        #expect(!(ConditionComparisonError.featurePrintUnavailable.localizedDescription.isEmpty))
        #expect(BiometricError.cancelled.localizedDescription == "Face ID was cancelled.")
    }

    @Test func `Network failure without acache shows the error`() async {
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.timedOut)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: OfflineCacheStore(inMemory: true))
        #expect(model.errorMessage == URLError(.timedOut).localizedDescription)
        #expect(model.filteredTools.isEmpty)
        #expect(model.emptyState == nil)
        #expect(model.resultSummary == "UNABLE TO REFRESH AVAILABLE TOOLS")
    }

    @Test func `Empty search and radius states`() async {
        let repository = InMemoryBorrowingRepository()
        let model = NearbyMapViewModel()
        await model.load(using: repository)
        #expect(model.emptyState == .noListings)

        repository.tools = [CoverageFixtures.tool(id: "far", name: "Ladder", latitude: 10, longitude: 10)]
        await model.load(using: repository)
        model.searchText = "drill"
        #expect(model.emptyState == .noSearchMatches)

        model.searchText = ""
        model.origin = CoverageFixtures.tool().coordinate
        model.radiusKilometers = 1
        #expect(model.emptyState == .outsideRadius)
    }

    @Test func `Unreadable photo and wrong code stay on screen`() async throws {
        let error = #expect(throws: (any Error).self) {
            try PhotoEncoding.jpeg(UIImage())
        }
        #expect(error?.localizedDescription == ConditionComparisonError.unreadableImage.localizedDescription)
        let service = ScriptedAuthenticationService()
        let verification = VerificationViewModel()
        verification.updateCode("000000")
        let rejected = await verification.verify(phoneNumber: "+94713123411", verificationID: DevAuthFixtures.localVerificationID, using: service)
        #expect(!(rejected))
        #expect(verification.errorMessage == "Incorrect verification code.")
        verification.updateCode("")
        #expect(verification.errorMessage == nil)
    }
}
