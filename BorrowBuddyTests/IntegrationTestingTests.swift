import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct IntegrationTestingTests {
    @Test func `Signup verification and onboarding stay connected`() async throws {
        let service = ScriptedAuthenticationService()
        service.currentUserID = nil
        let signUp = SignUpViewModel()
        signUp.fullName = "Jordan Lee"
        signUp.email = "Jordan@Example.com"
        signUp.password = "secret1"
        let signedUp = await signUp.signUp(using: service)
        #expect(signedUp)

        let phone = PhoneSignInViewModel()
        phone.format(DevAuthFixtures.testPhoneDigits)
        let verificationID = await phone.sendCode(using: service)
        let verification = VerificationViewModel()
        verification.updateCode(DevAuthFixtures.testVerificationCode)
        let verified = await verification.verify(phoneNumber: phone.fullPhoneNumber, verificationID: verificationID, using: service)
        #expect(verified)

        try await service.completeOnboarding()
        let onboarded = try await service.hasCompletedOnboarding()
        #expect(onboarded)
        #expect(service.currentUserID == "user-1")
    }

    @Test func `Nearby load writes the offline cache`() async {
        let repository = InMemoryBorrowingRepository()
        repository.tools = [.demo]
        let cache = OfflineCacheStore(inMemory: true)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: cache)
        #expect(cache.loadTools().map(\.id) == [BorrowingTool.demo.id])
        #expect(model.errorMessage == nil)
        #expect(model.hasLoaded)
    }

    @Test func `Nearby load falls back to saved tools`() async {
        let cache = OfflineCacheStore(inMemory: true)
        cache.saveTools([.demo])
        let repository = InMemoryBorrowingRepository()
        repository.error = URLError(.notConnectedToInternet)
        let model = NearbyMapViewModel()
        await model.load(using: repository, cache: cache)
        #expect(model.filteredTools.map(\.name) == ["Cordless Drill"])
        #expect(model.errorMessage == "Showing saved tools while you're offline.")
    }

    @Test func `Profile save reads back from the account repository`() async throws {
        let repository = InMemoryAccountRepository()
        let model = AccountSettingsViewModel()
        let saved = await model.saveProfile(displayName: " Jordan ", neighborhood: " Maple Grove ", phoneNumber: " +1 555 0100 ", using: repository)
        #expect(saved)
        #expect(model.successMessage == "Profile saved.")
        let loaded = try await repository.loadAccount()
        #expect(loaded.displayName == "Jordan")
        #expect(loaded.neighborhood == "Maple Grove")
        #expect(loaded.phoneNumber == "+1 555 0100")
        try await repository.recordStorePurchase(transactionID: "txn-1", productID: StoreCatalog.starterProductID, credits: 50, title: "Starter", detail: "Card")
        let balance = try await repository.loadAccount().creditBalance
        #expect(balance == 92)
    }
}
