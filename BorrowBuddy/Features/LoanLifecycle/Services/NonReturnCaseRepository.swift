import Foundation

protocol NonReturnCaseRepository {
    func openCase(
        reservationID: String,
        toolID: String,
        borrowerID: String,
        reason: String
    ) async throws -> String
}

final class DemoNonReturnCaseRepository: NonReturnCaseRepository {
    func openCase(
        reservationID: String,
        toolID: String,
        borrowerID: String,
        reason: String
    ) async throws -> String {
        "demo-non-return-case"
    }
}
