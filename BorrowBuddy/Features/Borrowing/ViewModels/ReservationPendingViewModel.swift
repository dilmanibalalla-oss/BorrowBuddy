import Combine
import Foundation

@MainActor
final class ReservationPendingViewModel: ObservableObject {
    @Published private(set) var eventMessage = "Permission needed"
    @Published private(set) var errorMessage: String?

    func addEvent(_ reservation: ReservationRecord, using service: EventReminderService) async {
        do {
            try await service.addReturnReminder(for: reservation)
            eventMessage = "Event added"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func watch(id: String, repository: BorrowingRepository, flow: BorrowingFlowStore) async {
        do {
            for try await reservation in repository.reservationUpdates(id: id) {
                flow.reservation = reservation
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
