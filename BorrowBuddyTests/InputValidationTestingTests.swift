import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct InputValidationTestingTests {
    @Test func `Required profile fields`() async {
        let repository = InMemoryAccountRepository()
        let model = AccountSettingsViewModel()
        let missingName = await model.saveProfile(displayName: "   ", neighborhood: "Maple Grove", phoneNumber: "1", using: repository)
        #expect(!(missingName))
        #expect(model.errorMessage == "Full name is required.")
        let missingNeighborhood = await model.saveProfile(displayName: "Jordan", neighborhood: " ", phoneNumber: "1", using: repository)
        #expect(!(missingNeighborhood))
        #expect(model.errorMessage == "Neighborhood is required.")
    }

    @Test func `Email password and code formats`() async {
        let service = ScriptedAuthenticationService()
        let signUp = SignUpViewModel()
        signUp.fullName = " "
        signUp.email = "jordan@example.com"
        signUp.password = "secret1"
        let emptyName = await signUp.signUp(using: service)
        #expect(!(emptyName))
        #expect(signUp.errorMessage == AuthenticationError.emptyFields.localizedDescription)

        signUp.fullName = "Jordan"
        signUp.email = "jordan-example"
        let invalidEmail = await signUp.signUp(using: service)
        #expect(!(invalidEmail))
        #expect(signUp.errorMessage == AuthenticationError.invalidEmail.localizedDescription)

        signUp.email = "jordan@example.com"
        signUp.password = "12345"
        #expect(!(signUp.canSubmit))
        let weakPassword = await signUp.signUp(using: service)
        #expect(!(weakPassword))
        #expect(signUp.errorMessage == AuthenticationError.weakPassword.localizedDescription)

        let verification = VerificationViewModel()
        verification.updateCode("12ab34!!")
        #expect(verification.code == "1234")
        verification.updateCode("123456789")
        #expect(verification.code == "123456")
        #expect(verification.errorMessage == nil)
        verification.updateCode("999999000")
        #expect(verification.code == "999999")
        #expect(verification.errorMessage == nil)
        #expect(verification.canVerify)
    }

    @Test func `Phone length strips invalid characters`() {
        let phone = PhoneSignInViewModel()
        phone.format("<script>alert(1)</script>000")
        #expect(!(phone.phoneNumber.contains("<")))
        #expect(!(phone.phoneNumber.contains("script")))
        #expect(!(phone.canContinue))

        phone.format(DevAuthFixtures.testPhoneDigits + "999")
        #expect(phone.phoneNumber.filter(\.isNumber).count == Country.defaultCountry.maxNationalDigits)
        #expect(phone.canContinue)

        phone.selectCountry(Country.all.first { $0.id == "SG" }!)
        phone.format("123456789")
        #expect(phone.phoneNumber.filter(\.isNumber).count == 8)
    }

    @Test func `Reservation day count cannot be zero`() {
        let quote = ReservationQuote.make(for: .demo, days: 0)
        #expect(quote.returnAt > quote.pickupAt)
        #expect(quote.rentalCredits == BorrowingTool.demo.dailyCredits)
        #expect(quote.totalHold == quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
    }
}
