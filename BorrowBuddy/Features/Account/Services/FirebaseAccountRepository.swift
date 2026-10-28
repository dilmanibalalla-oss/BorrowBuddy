//
//  FirebaseAccountRepository.swift
//  BorrowBuddy
//

import _LocationEssentials
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirebaseAccountRepository: AccountRepository {
    private let database = Firestore.firestore()

    func loadAccount() async throws -> AccountSummary {
        let user = try currentUser()
        let snapshot = try await database.collection("users").document(user.uid).getDocument()
        let data = snapshot.data() ?? [:]
        let shed = data["shedLocation"] as? [String: Any]
        let address = data["address"] as? [String: Any]
        let geo = data["location"] as? GeoPoint

        return AccountSummary(
            displayName: stringValue(data["displayName"])
                ?? user.displayName
                ?? "Neighbor",
            neighborhood: stringValue(data["neighborhood"]) ?? "",
            phoneNumber: stringValue(data["phoneNumber"])
                ?? user.phoneNumber
                ?? "",
            creditBalance: number(data["creditBalance"]).intValue,
            creditHeld: number(data["creditHeld"]).intValue,
            photoData: decodePhoto(data["photoData"]),
            latitude: geo?.latitude ?? (shed?["latitude"] as? NSNumber)?.doubleValue,
            longitude: geo?.longitude ?? (shed?["longitude"] as? NSNumber)?.doubleValue,
            streetAddress: stringValue(shed?["street"])
                ?? stringValue(address?["street"])
                ?? "",
            unit: stringValue(shed?["unit"])
                ?? stringValue(address?["unit"])
                ?? "",
            postalCode: stringValue(shed?["postalCode"])
                ?? stringValue(address?["postalCode"])
                ?? ""
        )
    }

    func loadLedger() async throws -> [WalletEntry] {
        let uid = try currentUser().uid
        let purchases = try await database.collection("users")
            .document(uid)
            .collection("walletTransactions")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()

        return purchases.documents.map { document in
            let data = document.data()
            return WalletEntry(
                id: document.documentID,
                title: stringValue(data["title"]) ?? "Wallet transaction",
                detail: stringValue(data["detail"]) ?? "",
                credits: number(data["credits"]).intValue
            )
        }
    }

    func updateProfile(displayName: String, neighborhood: String, phoneNumber: String) async throws {
        let user = try currentUser()
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNeighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPhone = trimmedPhone.isEmpty ? (user.phoneNumber ?? "") : trimmedPhone

        do {
            // Keep Auth profile in sync so Home ("Hey, …") and Account stay consistent.
            if user.displayName != trimmedName {
                let request = user.createProfileChangeRequest()
                request.displayName = trimmedName
                try await request.commitChanges()
            }

            var payload: [String: Any] = [
                "displayName": trimmedName,
                "neighborhood": trimmedNeighborhood,
                "phoneNumber": resolvedPhone,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if let email = user.email {
                payload["email"] = email
            }
            // Only seed wallet fields when the document is first created.
            let snapshot = try await database.collection("users").document(user.uid).getDocument()
            if !snapshot.exists {
                payload["creditBalance"] = 0
                payload["creditHeld"] = 0
                payload["createdAt"] = FieldValue.serverTimestamp()
            }

            try await database.collection("users").document(user.uid).setData(payload, merge: true)
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func updateProfilePhoto(_ data: Data) async throws {
        guard data.count <= 600_000 else {
            throw CommunityError.invalidInput("Choose a smaller profile photo.")
        }
        let userID = try currentUser().uid
        do {
            try await database.collection("users").document(userID).setData(
                [
                    "photoData": data,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func loadNotificationSettings() async throws -> NotificationSettings {
        let userID = try currentUser().uid
        let snapshot = try await database.collection("users").document(userID).getDocument()
        let values = snapshot.data()?["notificationPreferences"] as? [String: Bool] ?? [:]
        return NotificationSettings(
            reservationUpdates: values["reservationUpdates"] ?? true,
            pickupReminders: values["pickupReminders"] ?? true,
            returnReminders: values["returnReminders"] ?? true,
            neighborhoodActivity: values["neighborhoodActivity"] ?? false
        )
    }

    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        let userID = try currentUser().uid
        do {
            try await database.collection("users").document(userID).setData(
                [
                    "notificationPreferences": settings.dictionary,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func loadPreferredPaymentMethod() async throws -> String {
        let userID = try currentUser().uid
        let snapshot = try await database.collection("users").document(userID).getDocument()
        return stringValue(snapshot.data()?["preferredPaymentMethod"]) ?? "Apple Pay"
    }

    func updatePreferredPaymentMethod(_ method: String) async throws {
        let userID = try currentUser().uid
        do {
            try await database.collection("users").document(userID).setData(
                [
                    "preferredPaymentMethod": method,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        } catch {
            throw mapFirestoreError(error)
        }
    }

    private func currentUser() throws -> User {
        guard let user = Auth.auth().currentUser else {
            throw CommunityError.signInRequired
        }
        return user
    }

    private func number(_ value: Any?) -> NSNumber {
        value as? NSNumber ?? 0
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    private func decodePhoto(_ value: Any?) -> Data? {
        if let data = value as? Data {
            return data
        }
        if let data = value as? NSData {
            return data as Data
        }
        if let base64 = value as? String, let data = Data(base64Encoded: base64) {
            return data
        }
        return nil
    }

    private func mapFirestoreError(_ error: Error) -> Error {
        let nsError = error as NSError
        if nsError.domain == FirestoreErrorDomain,
           nsError.code == FirestoreErrorCode.permissionDenied.rawValue {
            return CommunityError.invalidInput(
                "Firestore blocked this save. In Firebase Console → Firestore → Rules, allow signed-in users to read/write their own users/{uid} document."
            )
        }
        return error
    }
}
