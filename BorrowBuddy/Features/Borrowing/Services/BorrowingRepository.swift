import Foundation

protocol BorrowingRepository {
    func fetchNearbyTools() async throws -> [BorrowingTool]
    func fetchMyLoans() async throws -> [ReservationRecord]
    func addTool(_ tool: BorrowingTool) async throws -> String
    func updateTool(_ tool: BorrowingTool) async throws
    func deleteTool(id: String) async throws
    func createReservation(tool: BorrowingTool, quote: ReservationQuote) async throws -> ReservationRecord
    func fetchReservation(id: String) async throws -> ReservationRecord
    func reservationUpdates(id: String) -> AsyncThrowingStream<ReservationRecord, Error>
}

extension BorrowingRepository {
    func fetchReservation(id: String) async throws -> ReservationRecord {
        for try await loan in reservationUpdates(id: id) { return loan }
        throw CommunityError.invalidInput("The reservation could not be loaded. Open it again from your loan history.")
    }
}

final class DemoBorrowingRepository: BorrowingRepository {
    func fetchNearbyTools() async throws -> [BorrowingTool] {
        [BorrowingTool.demo]
    }

    func fetchMyLoans() async throws -> [ReservationRecord] {
        []
    }

    func addTool(_ tool: BorrowingTool) async throws -> String {
        tool.id.isEmpty ? UUID().uuidString : tool.id
    }

    func updateTool(_ tool: BorrowingTool) async throws {}

    func deleteTool(id: String) async throws {}

    func createReservation(tool: BorrowingTool, quote: ReservationQuote) async throws -> ReservationRecord {
        try await Task.sleep(for: .milliseconds(450))
        return ReservationRecord(
            id: UUID().uuidString,
            receipt: "LC-28491",
            toolID: tool.id,
            toolName: tool.name,
            ownerID: tool.ownerID,
            borrowerID: "demo-borrower",
            pickupAt: quote.pickupAt,
            returnAt: quote.returnAt,
            totalHold: quote.totalHold,
            status: .pending,
            requestedAt: Date(),
            pickupAddress: tool.pickupAddress,
            ownerName: tool.ownerName,
            rentalCredits: quote.rentalCredits,
            serviceCredits: quote.serviceCredits,
            depositCredits: quote.depositCredits,
            toolSnapshot: tool
        )
    }

    func reservationUpdates(id: String) -> AsyncThrowingStream<ReservationRecord, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}
