import Combine
import Foundation

@MainActor
final class ReservationReviewViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func authorize(
        repository: BorrowingRepository,
        tool: BorrowingTool,
        quote: ReservationQuote
    ) async -> ReservationRecord? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await repository.createReservation(tool: tool, quote: quote)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
