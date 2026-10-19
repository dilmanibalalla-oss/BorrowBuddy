import UserNotifications
import Foundation
#if canImport(FirebaseAuth) && canImport(FirebaseMessaging)
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore
#endif

@MainActor
final class LoanNotificationService {
    func schedule(for loan: ReservationRecord, preferences: NotificationSettings) async {
        let center = UNUserNotificationCenter.current()
        let ids = ["pickup", "return-day", "return-hour"].map { "loan-\(loan.id)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard loan.isOpen else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        if loan.status == .pending && preferences.pickupReminders {
            await add(id: ids[0], title: "Pickup reminder", body: loan.toolName, at: loan.pickupAt.addingTimeInterval(-3600))
        }
        if loan.status == .active && loan.lifecycleStage != .awaitingReview && preferences.returnReminders {
            await add(id: ids[1], title: "Return due tomorrow", body: loan.toolName, at: loan.returnAt.addingTimeInterval(-86400))
            await add(id: ids[2], title: "Return due in two hours", body: loan.toolName, at: loan.returnAt.addingTimeInterval(-7200))
        }
    }

    private func add(id: String, title: String, body: String, at date: Date) async {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title; content.body = body; content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func registerToken(_ token: String? = nil) async {
        #if canImport(FirebaseAuth) && canImport(FirebaseMessaging)
        guard FirebaseBootstrap.isConfigured, let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let value: String
            if let token { value = token } else { value = try await Messaging.messaging().token() }
            var deviceID = UserDefaults.standard.string(forKey: "notificationDeviceID")
            if deviceID == nil { deviceID = UUID().uuidString; UserDefaults.standard.set(deviceID, forKey: "notificationDeviceID") }
            guard let deviceID else { return }
            try await Firestore.firestore().collection("users").document(uid).collection("devices").document(deviceID)
                .setData(["token": value, "updatedAt": FieldValue.serverTimestamp()])
        } catch { /* Push failure does not block login; local reminders remain available. */ }
        #endif
    }

    func unregister() async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        #if canImport(FirebaseAuth) && canImport(FirebaseMessaging)
        if let uid = Auth.auth().currentUser?.uid, let deviceID = UserDefaults.standard.string(forKey: "notificationDeviceID") {
            try? await Firestore.firestore().collection("users").document(uid).collection("devices").document(deviceID).delete()
        }
        try? await Messaging.messaging().deleteToken()
        #endif
    }
}
