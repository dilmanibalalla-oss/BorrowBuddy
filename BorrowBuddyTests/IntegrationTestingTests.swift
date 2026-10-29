import XCTest
@testable import BorrowBuddy

@MainActor
final class IntegrationTestingTests: XCTestCase {
    func testSignupVerificationAndOnboardingStayConnected() async throws {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let signUp = SignUpViewModel()
        signUp.fullName = "Jordan Lee"
        signUp.email = "Jordan@Example.com"
        signUp.password = "secret1"
        let signedUp = await signUp.signUp(using: service)
        XCTAssertTrue(signedUp)

        let phone = PhoneSignInViewModel()
        phone.format(DevAuthFixtures.testPhoneDigits)
        let verificationID = await phone.sendCode(using: service)
        let verification = VerificationViewModel()
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        let verified = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        XCTAssertTrue(verified)

        try await service.completeOnboarding()
        let onboarded = try await service.hasCompletedOnboarding()
        XCTAssertTrue(onboarded)
        XCTAssertEqual(service.currentUserID, "user-1")
    }

    func testNearbyLoadWritesTheOfflineCache() async {
        let repository = InMemoryBorrowingRepository()
        repository.tools = [.demo]
        let cache = OfflineCacheStore(inMemory: true)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: cache)
        XCTAssertEqual(cache.loadTools().map(\.id), [BorrowingTool.demo.id])
        XCTAssertNil(model.errorMessage)
        XCTAssertTrue(model.hasLoaded)
    }

    func testNearbyLoadFallsBackToSavedTools() async {
        let cache = OfflineCacheStore(inMemory: true)
        cache.saveTools([.demo])
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.notConnectedToInternet)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: cache)
        XCTAssertEqual(model.filteredTools.map(\.name), ["Cordless Drill"])
        XCTAssertEqual(model.errorMessage, "Showing saved tools while you're offline.")
    }

    func testProfileSaveReadsBackFromTheAccountRepository() async throws {
        let repository = InMemoryAccountRepository()
        let model = AccountSettingsViewModel()
        let saved = await model.saveProfile(displayName: " Jordan ", neighborhood: " Maple Grove ", phoneNumber: " +1 555 0100 ", using: repository)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.successMessage, "Profile saved.")
        let loaded = try await repository.loadAccount()
        XCTAssertEqual(loaded.displayName, "Jordan")
        XCTAssertEqual(loaded.neighborhood, "Maple Grove")
        XCTAssertEqual(loaded.phoneNumber, "+1 555 0100")
        try await repository.recordStorePurchase(transactionID: "txn-1", productID: StoreCatalog.starterProductID, credits: 50, title: "Starter", detail: "Card")
        let balance = try await repository.loadAccount().creditBalance
        XCTAssertEqual(balance, 92)
    }
}
