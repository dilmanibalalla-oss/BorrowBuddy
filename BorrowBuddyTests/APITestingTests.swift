import XCTest
@testable import BorrowBuddy

@MainActor
final class APITestingTests: XCTestCase {
    func testLoanPayloadRequiresTheResponseFields() {
        XCTAssertNil(FirestoreModels.loan(id: "missing", data: ["receipt": "LC-1"]))

        let pickup = Date(timeIntervalSince1970: 1_700_000_000)
        let record = FirestoreModels.loan(id: "loan-9", data: [
            "receipt": "LC-9",
            "toolId": "demo-drill",
            "toolName": "Cordless Drill",
            "ownerId": "owner",
            "borrowerId": "borrower",
            "status": "active",
            "lifecycleStage": "active",
            "totalHold": NSNumber(value: 30),
            "pickupAt": pickup,
            "returnAt": pickup.addingTimeInterval(86_400),
            "requestedAt": pickup,
            "photoData": "aGVsbG8="
        ])
        XCTAssertEqual(record?.id, "loan-9")
        XCTAssertEqual(record?.status, .active)
        XCTAssertEqual(record?.lifecycleStage, .active)
        XCTAssertEqual(record?.totalHold, 30)
        XCTAssertEqual(record?.toolSnapshot.photoData, Data("hello".utf8))
    }

    func testUnknownStatusAndEmptyPhotoFallBackSafely() {
        let record = FirestoreModels.loan(id: "loan-2", data: [
            "receipt": "LC-2",
            "toolId": "tool",
            "toolName": "Saw",
            "ownerId": "owner",
            "borrowerId": "borrower",
            "status": "not-a-status",
            "photoData": ""
        ])
        XCTAssertEqual(record?.status, .pending)
        XCTAssertEqual(record?.lifecycleStage, .pending)
        XCTAssertNil(record?.toolSnapshot.photoData)
    }

    func testAuthResponsesMapStatusCodes() async {
        let cases: [(Int, String)] = [
            (17007, "An account with this email already exists. Try logging in."),
            (17008, "Please enter a valid email address."),
            (17026, "Password must be at least 6 characters."),
            (17020, "Network error. Check your connection and try again."),
            (999, "Service unavailable.")
        ]
        for (code, message) in cases {
            let model = SignUpViewModel()
            model.fullName = "Jordan"
            model.email = "jordan@example.com"
            model.password = "secret1"
            let service = ScriptedAuthenticationService()
            service.signUpError = NSError(domain: "FIRAuth", code: code, userInfo: [NSLocalizedDescriptionKey: "Service unavailable."])
            let signedUp = await model.signUp(using: service)
            XCTAssertFalse(signedUp)
            XCTAssertEqual(model.errorMessage, message)
        }
    }

    func testMissingReservationResponseThrows() async {
        let repository = InMemoryBorrowingRepository()
        do {
            _ = try await repository.fetchReservation(id: "missing")
            XCTFail("A finished stream should be an error.")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                "The reservation could not be loaded. Open it again from your loan history."
            )
        }

        repository.error = URLError(.badServerResponse)
        do {
            _ = try await repository.fetchNearbyTools()
            XCTFail("The repository error should surface.")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }
}
