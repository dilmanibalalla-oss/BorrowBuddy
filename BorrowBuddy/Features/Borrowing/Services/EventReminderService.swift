import EventKit

@MainActor
final class EventReminderService {
    private let eventStore = EKEventStore()

    func addReturnReminder(for reservation: ReservationRecord) async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw CocoaError(.userCancelled)
        }
        let key = "return-calendar-event-\(reservation.id)"
        let previousID = UserDefaults.standard.string(forKey: key)
        let event = previousID.flatMap { eventStore.event(withIdentifier: $0) } ?? EKEvent(eventStore: eventStore)
        event.title = "Return \(reservation.toolName)"
        event.startDate = reservation.returnAt
        event.endDate = reservation.returnAt.addingTimeInterval(30 * 60)
        guard let calendar = event.calendar ?? eventStore.defaultCalendarForNewEvents else {
            throw CommunityError.invalidInput("Add a writable calendar in Settings before creating a reminder.")
        }
        event.calendar = calendar
        event.alarms = []
        event.addAlarm(EKAlarm(relativeOffset: -24 * 60 * 60))
        event.addAlarm(EKAlarm(relativeOffset: -2 * 60 * 60))
        try eventStore.save(event, span: .thisEvent)
        if let id = event.eventIdentifier { UserDefaults.standard.set(id, forKey: key) }
    }

    func addListingWindow(toolID: String, name: String, from: Date, until: Date) async throws {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: from)
        let lastDay = calendar.startOfDay(for: until)
        guard lastDay >= start else {
            throw CommunityError.invalidInput("Choose an end date on or after the start date.")
        }
        let granted = try await eventStore.requestFullAccessToEvents()
        guard granted else {
            throw CocoaError(.userCancelled)
        }
        let key = "listing-calendar-event-\(toolID)"
        let previousID = UserDefaults.standard.string(forKey: key)
        let event = previousID.flatMap { eventStore.event(withIdentifier: $0) } ?? EKEvent(eventStore: eventStore)
        event.title = "Lending \(name)"
        event.isAllDay = true
        event.startDate = start
        event.endDate = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay.addingTimeInterval(86_400)
        guard let destination = event.calendar ?? eventStore.defaultCalendarForNewEvents else {
            throw CommunityError.invalidInput("Add a writable calendar in Settings before saving these dates.")
        }
        event.calendar = destination
        event.alarms = [EKAlarm(relativeOffset: -3600)]
        try eventStore.save(event, span: .thisEvent)
        if let id = event.eventIdentifier { UserDefaults.standard.set(id, forKey: key) }
    }
}
