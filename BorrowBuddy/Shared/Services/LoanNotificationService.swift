import UserNotifications
import Foundation
#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
#endif

extension Notification.Name {
    static let borrowBuddyDidNotify = Notification.Name("borrowbuddy.didNotify")
}

@MainActor
final class LoanNotificationService {
    func schedule(for loan: ReservationRecord, preferences: NotificationSettings) async {
        let center = UNUserNotificationCenter.current()
        let ids = ["pickup", "return-day", "return-hour", "due", "overdue", "grace-ended", "escalation", "owner-grace", "owner-paused", "owner-escalation"].map { "loan-\(loan.id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard loan.isOpen else { return }
        await ensureAuthorization()
        let settings = await center.notificationSettings()
        let canNotify = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral
        #if canImport(FirebaseAuth)
        let currentUserID = Auth.auth().currentUser?.uid
        let isBorrower = currentUserID == loan.borrowerID
        let isOwner = currentUserID == loan.ownerID
        #else
        let isBorrower = true
        let isOwner = false
        #endif
        let tracksReturn = loan.status == .active && loan.lifecycleStage != .awaitingReview && preferences.returnReminders
        var upcoming: [(id: String, title: String, body: String, at: Date)] = []
        if loan.status == .pending && preferences.pickupReminders {
            upcoming.append((ids[0], "Pickup reminder", loan.toolName, loan.pickupAt.addingTimeInterval(-3600)))
        }
        if isBorrower && tracksReturn {
            for reminder in ReturnReminderSchedule.borrowerReturnReminders(returnAt: loan.returnAt) {
                let body = reminder.suffix == "due" ? "\(loan.toolName) is due." : loan.toolName
                let index = ["return-day", "return-hour", "due", "overdue", "grace-ended"].firstIndex(of: reminder.suffix) ?? 0
                upcoming.append((ids[index + 1], reminder.title, body, reminder.fireAt))
            }
            upcoming.append((ids[6], "Support escalation", "This case is eligible for support escalation and human review.", loan.returnAt.addingTimeInterval(NonReturnPolicy.escalationInterval)))
        }
        if isOwner && tracksReturn {
            upcoming.append((ids[7], "Overdue grace period", "Both neighbors are notified. You can message each other or agree an extension.", loan.returnAt.addingTimeInterval(ReturnReminderSchedule.overdue)))
            upcoming.append((ids[8], "Borrowing paused", "New borrowing is blocked while this loan stays unresolved.", loan.returnAt.addingTimeInterval(NonReturnPolicy.graceInterval)))
            upcoming.append((ids[9], "Support escalation", "This case is eligible for support escalation and human review.", loan.returnAt.addingTimeInterval(NonReturnPolicy.escalationInterval)))
        }
        if canNotify {
            for item in upcoming {
                await add(id: item.id, title: item.title, body: item.body, at: item.at)
            }
        }
        if let notice = NonReturnPolicy.notice(for: loan, now: Date()), isBorrower || isOwner {
            let stageID = "loan-\(loan.id)-stage-\(notice.status.rawValue)"
            if announced.insert(stageID).inserted {
                await present(title: notice.title, body: notice.message)
            }
        } else {
            let future = upcoming.filter { $0.at > Date() }
            let next = future.min { $0.at < $1.at }
                ?? upcoming.filter { $0.at > Date().addingTimeInterval(-7 * 86_400) }.max { $0.at < $1.at }
            if let next, announced.insert(next.id).inserted {
                await present(title: next.title, body: next.body)
            }
        }
    }

    func watchLoanMessages(_ loans: [ReservationRecord]) {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let userID = Auth.auth().currentUser?.uid else { return }
        for loan in loans where loan.isOpen && messageListeners[loan.id] == nil {
            let reservationID = loan.id
            let storageKey = "seen-loan-notes-\(reservationID)"
            var seen = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
            var primed = false
            let listener = Firestore.firestore()
                .collection("reservations").document(reservationID)
                .collection("notes")
                .order(by: "createdAt")
                .addSnapshotListener { snapshot, _ in
                    let documents = snapshot?.documents ?? []
                    let unseen = documents.filter { !seen.contains($0.documentID) }
                    seen.formUnion(documents.map(\.documentID))
                    UserDefaults.standard.set(Array(seen.suffix(80)), forKey: storageKey)
                    let incoming = unseen.filter { ($0.data()["authorId"] as? String ?? "") != userID }
                    let latest = incoming.last
                    if !primed {
                        primed = true
                        let created = (latest?.data()["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
                        guard created > Date().addingTimeInterval(-7 * 86_400) else { return }
                    }
                    guard let latest else { return }
                    let body = latest.data()["message"] as? String ?? "New loan note"
                    Task { @MainActor in
                        await self.present(title: "New message", body: body)
                    }
                }
            messageListeners[reservationID] = listener
        }
        #endif
    }

    func stopWatchingMessages() {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        messageListeners.values.forEach { $0.remove() }
        messageListeners.removeAll()
        #endif
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
    private var messageListeners: [String: ListenerRegistration] = [:]
    #endif
    private var announced: Set<String> = []

    private func ensureAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    private func present(title: String, body: String) async {
        NotificationCenter.default.post(
            name: .borrowBuddyDidNotify,
            object: nil,
            userInfo: ["title": title, "body": body]
        )
        await ensureAuthorization()
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional || settings.authorizationStatus == .ephemeral else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        )
    }

    private func add(id: String, title: String, body: String, at date: Date) async {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func deliver(title: String, body: String) async {
        await present(title: title, body: body)
    }

    func registerToken() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func unregister() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
