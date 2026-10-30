import Foundation
import Testing
@testable import BorrowBuddy

@MainActor
struct APITestingTests {
    @Test func `Loan payload requires the response fields`() {
        #expect(FirestoreModels.loan(id: "missing", data: ["receipt": "LC-1"]) == nil)

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
        #expect(record?.id == "loan-9")
        #expect(record?.status == .active)
        #expect(record?.lifecycleStage == .active)
        #expect(record?.totalHold == 30)
        #expect(record?.toolSnapshot.photoData == Data("hello".utf8))
    }

    @Test func `Unknown status and empty photo fall back safely`() {
        let record = FirestoreModels.loan(id: "loan-2", data: [
            "receipt": "LC-2",
            "toolId": "tool",
            "toolName": "Saw",
            "ownerId": "owner",
            "borrowerId": "borrower",
            "status": "not-a-status",
            "photoData": ""
        ])
        #expect(record?.status == .pending)
        #expect(record?.lifecycleStage == .pending)
        #expect(record?.toolSnapshot.photoData == nil)
    }

    @Test func `Auth responses map status codes`() async {
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
            #expect(!(signedUp))
            #expect(model.errorMessage == message)
        }
    }

    @Test func `Open meteo forecast decodes shed weather`() throws {
        let json = #"{"current":{"temperature_2m":22.4,"weather_code":0}}"#.data(using: .utf8)!
        let weather = try ShedWeatherService.weather(from: json)
        #expect(weather.temperatureCelsius == 22.4)
        #expect(weather.condition == "clear")
        #expect(weather.summary == "22°C and clear at your shed")

        let url = ShedWeatherService.requestURL(latitude: 43.65, longitude: -79.38)
        #expect(url?.scheme == "https")
        #expect(url?.host == "api.open-meteo.com")
        #expect(ShedWeatherService.requestURL(latitude: 120, longitude: 0) == nil)
        #expect(throws: (any Error).self) { try ShedWeatherService.weather(from: Data("{}".utf8)) }
    }

    @Test func `Missing reservation response throws`() async {
        let repository = InMemoryBorrowingRepository()
        do {
            _ = try await repository.fetchReservation(id: "missing")
            Issue.record("A finished stream should be an error.")
        } catch {
            #expect(error.localizedDescription == "The reservation could not be loaded. Open it again from your loan history.")
        }

        repository.error = URLError(.badServerResponse)
        do {
            _ = try await repository.fetchNearbyTools()
            Issue.record("The repository error should surface.")
        } catch {
            #expect((error as? URLError)?.code == .badServerResponse)
        }
    }
}
