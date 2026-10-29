import XCTest
@testable import BorrowBuddy

@MainActor
final class InputValidationTestingTests: XCTestCase {
    func testRequiredProfileFields() async {
        let repository = InMemoryAccountRepository()
        let model = AccountSettingsViewModel()
        let missingName = await model.saveProfile(displayName: "   ", neighborhood: "Maple Grove", phoneNumber: "1", using: repository)
        XCTAssertFalse(missingName)
        XCTAssertEqual(model.errorMessage, "Full name is required.")
        let missingNeighborhood = await model.saveProfile(displayName: "Jordan", neighborhood: " ", phoneNumber: "1", using: repository)
        XCTAssertFalse(missingNeighborhood)
        XCTAssertEqual(model.errorMessage, "Neighborhood is required.")
    }

    func testEmailPasswordAndCodeFormats() async {
        let service = ScriptedAuthenticationService()
        let signUp = SignUpViewModel()
        signUp.fullName = " "
        signUp.email = "jordan@example.com"
        signUp.password = "secret1"
        let emptyName = await signUp.signUp(using: service)
        XCTAssertFalse(emptyName)
        XCTAssertEqual(signUp.errorMessage, AuthenticationError.emptyFields.localizedDescription)

        signUp.fullName = "Jordan"
        signUp.email = "jordan-example"
        let invalidEmail = await signUp.signUp(using: service)
        XCTAssertFalse(invalidEmail)
        XCTAssertEqual(signUp.errorMessage, AuthenticationError.invalidEmail.localizedDescription)

        signUp.email = "jordan@example.com"
        signUp.password = "12345"
        XCTAssertFalse(signUp.canSubmit)
        let weakPassword = await signUp.signUp(using: service)
        XCTAssertFalse(weakPassword)
        XCTAssertEqual(signUp.errorMessage, AuthenticationError.weakPassword.localizedDescription)

        let verification = VerificationViewModel()
        verification.updateCode("12ab34!!")
        XCTAssertEqual(verification.code, "1234")
        verification.updateCode("123456789")
        XCTAssertEqual(verification.code, "123456")
        XCTAssertNil(verification.errorMessage)
        verification.updateCode("999999000")
        XCTAssertEqual(verification.code, "999999")
        XCTAssertEqual(verification.errorMessage, "Incorrect verification code.")
    }

    func testPhoneLengthStripsInvalidCharacters() {
        let phone = PhoneSignInViewModel()
        phone.format("<script>alert(1)</script>000")
        XCTAssertFalse(phone.phoneNumber.contains("<"))
        XCTAssertFalse(phone.phoneNumber.contains("script"))
        XCTAssertFalse(phone.canContinue)

        phone.format(DevAuthFixtures.testPhoneDigits + "999")
        XCTAssertEqual(phone.phoneNumber.filter(\.isNumber).count, Country.defaultCountry.maxNationalDigits)
        XCTAssertTrue(phone.canContinue)

        phone.selectCountry(Country.all.first { $0.id == "SG" }!)
        phone.format("123456789")
        XCTAssertEqual(phone.phoneNumber.filter(\.isNumber).count, 8)
    }

    func testReservationDayCountCannotBeZero() {
        let quote = ReservationQuote.make(for: .demo, days: 0)
        XCTAssertGreaterThan(quote.returnAt, quote.pickupAt)
        XCTAssertEqual(quote.rentalCredits, BorrowingTool.demo.dailyCredits)
        XCTAssertEqual(quote.totalHold, quote.rentalCredits + quote.serviceCredits + quote.depositCredits)
    }
}
