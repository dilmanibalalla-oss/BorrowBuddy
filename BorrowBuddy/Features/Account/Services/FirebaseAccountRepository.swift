//
//  FirebaseAccountRepository.swift
//  BorrowBuddy
//

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
                ?? "",
            identityVerified: data["identityVerified"] as? Bool ?? false,
            addressConfirmed: data["addressConfirmed"] as? Bool ?? false,
            isPro: data["isPro"] as? Bool ?? false
        )
    }

    func loadLedger() async throws -> [WalletEntry] {
        let uid = try currentUser().uid
        let user = database.collection("users").document(uid)
        async let purchases = user
            .collection("walletTransactions")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .getDocuments()
        async let schedule = user
            .collection("scheduleEvents")
            .limit(to: 200)
            .getDocuments()

        let creditEntries = try await purchases.documents.map { document in
            let data = document.data()
            return WalletEntry(
                id: document.documentID,
                title: stringValue(data["title"]) ?? "Wallet transaction",
                detail: stringValue(data["detail"]) ?? "",
                credits: number(data["credits"]).intValue,
                kind: .credit,
                recordedAt: FirestoreModels.date(data["createdAt"]) ?? .distantPast
            )
        }
        let activities = try await schedule.documents.compactMap { document -> WalletEntry? in
            guard let event = scheduleEvent(id: document.documentID, data: document.data(), includeCleared: false) else {
                return nil
            }
            return WalletEntry(
                id: event.id,
                title: event.title,
                detail: event.detail,
                credits: 0,
                kind: event.kind,
                recordedAt: event.occursAt
            )
        }
        return (creditEntries + activities).sorted { $0.recordedAt > $1.recordedAt }
    }

    func loadScheduleEvents() async throws -> [ScheduleEvent] {
        let uid = try currentUser().uid
        let snapshot = try await database.collection("users")
            .document(uid)
            .collection("scheduleEvents")
            .limit(to: 200)
            .getDocuments()
        return snapshot.documents
            .compactMap { scheduleEvent(id: $0.documentID, data: $0.data(), includeCleared: true) }
            .sorted { $0.occursAt < $1.occursAt }
    }

    func syncScheduleEvents(for loans: [ReservationRecord]) async throws {
        let uid = try currentUser().uid
        let collection = database.collection("users").document(uid).collection("scheduleEvents")
        let existingSnapshot = try await collection.getDocuments()
        var existing: [String: [String: Any]] = [:]
        for document in existingSnapshot.documents {
            existing[document.documentID] = document.data()
        }

        let batch = database.batch()
        var writes = 0
        for loan in loans where loan.borrowerID == uid || loan.ownerID == uid {
            let role = loan.borrowerID == uid ? "borrower" : "owner"
            for kind in [WalletEntry.Kind.pickup, .return] {
                let id = "\(loan.id)_\(kind.rawValue)"
                let occursAt = kind == .pickup ? loan.pickupAt : loan.returnAt
                let title = "\(kind == .pickup ? "Pickup" : "Return") · \(loan.toolName)"
                let detail = scheduleDetail(kind: kind, loan: loan, userID: uid)
                let cancelled = loan.status == .cancelled
                if let data = existing[id],
                   scheduleUnchanged(
                    data,
                    title: title,
                    detail: detail,
                    occursAt: occursAt,
                    address: loan.pickupAddress,
                    loanStatus: loan.status.rawValue,
                    role: role,
                    cancelled: cancelled
                   ) {
                    continue
                }

                var payload: [String: Any] = [
                    "kind": kind.rawValue,
                    "reservationId": loan.id,
                    "toolName": loan.toolName,
                    "title": title,
                    "detail": detail,
                    "role": role,
                    "occursAt": Timestamp(date: occursAt),
                    "address": loan.pickupAddress,
                    "loanStatus": loan.status.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                if existing[id] == nil {
                    payload["createdAt"] = FieldValue.serverTimestamp()
                }
                let previousDate = existing[id].flatMap { FirestoreModels.date($0["occursAt"]) }
                let moved = previousDate.map { abs($0.timeIntervalSince(occursAt)) > 60 } ?? false
                if cancelled || existing[id] == nil || moved {
                    payload["activityCleared"] = cancelled
                }
                batch.setData(payload, forDocument: collection.document(id), merge: true)
                writes += 1
            }
        }
        guard writes > 0 else { return }
        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func clearScheduleActivities(ids: [String]) async throws {
        let unique = Array(Set(ids.filter { !$0.isEmpty }))
        guard !unique.isEmpty else { return }
        let uid = try currentUser().uid
        let collection = database.collection("users").document(uid).collection("scheduleEvents")
        let batch = database.batch()
        for id in unique {
            batch.updateData(
                [
                    "activityCleared": true,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: collection.document(id)
            )
        }
        do {
            try await batch.commit()
        } catch {
            throw mapFirestoreError(error)
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
            // Award the starting balance only when this account has never had one.
            let snapshot = try await database.collection("users").document(user.uid).getDocument()
            if snapshot.data()?["creditBalance"] == nil {
                payload["creditBalance"] = AccountSummary.newAccountCredits
                payload["creditHeld"] = 0
                if !snapshot.exists {
                    payload["createdAt"] = FieldValue.serverTimestamp()
                }
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
        return stringValue(snapshot.data()?["preferredPaymentMethod"]) ?? "StoreKit 2"
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

    func recordStorePurchase(
        transactionID: String,
        productID: String,
        credits: Int,
        title: String,
        detail: String
    ) async throws {
        guard credits > 0, !transactionID.isEmpty else {
            throw CommunityError.invalidInput("This purchase could not be applied.")
        }
        let userID = try currentUser().uid
        let userReference = database.collection("users").document(userID)
        let purchaseReference = userReference.collection("walletTransactions").document(transactionID)
        try await commitTransaction { transaction in
            let existing = try transaction.getDocument(purchaseReference)
            guard !existing.exists else { return }
            let userSnapshot = try transaction.getDocument(userReference)
            let balance = self.number(userSnapshot.data()?["creditBalance"]).intValue
            transaction.setData(
                [
                    "creditBalance": balance + credits,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                forDocument: userReference,
                merge: true
            )
            transaction.setData(
                [
                    "title": title,
                    "detail": detail,
                    "credits": credits,
                    "productID": productID,
                    "source": "storekit2",
                    "createdAt": FieldValue.serverTimestamp()
                ],
                forDocument: purchaseReference
            )
        }
    }

    func activateProMembership(transactionID: String) async throws {
        let userID = try currentUser().uid
        let userReference = database.collection("users").document(userID)
        let welcomeReference = userReference.collection("walletTransactions").document("pro-welcome")
        try await commitTransaction { transaction in
            let userSnapshot = try transaction.getDocument(userReference)
            let welcome = try transaction.getDocument(welcomeReference)
            var userUpdate: [String: Any] = [
                "isPro": true,
                "proTransactionID": transactionID,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            if !welcome.exists {
                let balance = self.number(userSnapshot.data()?["creditBalance"]).intValue
                let welcomeCredits = MembershipPolicy.proWelcomeCredits
                userUpdate["creditBalance"] = balance + welcomeCredits
                userUpdate["proWelcomeGranted"] = true
                transaction.setData(
                    [
                        "title": "Pro welcome pack",
                        "detail": "BorrowBuddy Pro · 10 LendCredits",
                        "credits": welcomeCredits,
                        "productID": StoreCatalog.proMonthlyProductID,
                        "source": "storekit2",
                        "createdAt": FieldValue.serverTimestamp()
                    ],
                    forDocument: welcomeReference
                )
            }
            transaction.setData(userUpdate, forDocument: userReference, merge: true)
        }
    }

    func setProMembership(active: Bool) async throws {
        let userID = try currentUser().uid
        do {
            try await database.collection("users").document(userID).setData(
                [
                    "isPro": active,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        } catch {
            throw mapFirestoreError(error)
        }
    }

    func saveIdentityVerification(documentData: Data) async throws {
        guard documentData.count <= 600_000 else {
            throw CommunityError.invalidInput("Choose a smaller photo of your ID.")
        }
        let userID = try currentUser().uid
        do {
            try await database.collection("users").document(userID).setData(
                [
                    "identityVerified": true,
                    "addressConfirmed": true,
                    "idDocumentData": documentData,
                    "identityVerifiedAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        } catch {
            throw mapFirestoreError(error)
        }
    }

    private func commitTransaction(_ updates: @escaping (Transaction) throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer in
                do {
                    try updates(transaction)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }, completion: { _, error in
                if let error {
                    continuation.resume(throwing: self.mapFirestoreError(error))
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }

    private func scheduleEvent(id: String, data: [String: Any], includeCleared: Bool) -> ScheduleEvent? {
        guard let kind = WalletEntry.Kind(rawValue: stringValue(data["kind"]) ?? ""),
              kind == .pickup || kind == .return else {
            return nil
        }
        let status = stringValue(data["loanStatus"]) ?? ReservationStatus.pending.rawValue
        guard status != ReservationStatus.cancelled.rawValue else { return nil }
        let cleared = data["activityCleared"] as? Bool ?? false
        if cleared && !includeCleared { return nil }
        guard let occursAt = FirestoreModels.date(data["occursAt"]) else { return nil }
        let fallback = kind == .pickup ? "Pickup" : "Return"
        return ScheduleEvent(
            id: id,
            kind: kind,
            reservationID: stringValue(data["reservationId"]) ?? "",
            title: stringValue(data["title"]) ?? fallback,
            detail: stringValue(data["detail"]) ?? "",
            occursAt: occursAt,
            address: stringValue(data["address"]) ?? "",
            loanStatus: status
        )
    }

    private func scheduleDetail(kind: WalletEntry.Kind, loan: ReservationRecord, userID: String) -> String {
        let isBorrower = loan.borrowerID == userID
        let other: String
        if isBorrower {
            other = loan.ownerName.isEmpty ? "the owner" : loan.ownerName
        } else {
            other = loan.borrowerName.isEmpty ? "the borrower" : loan.borrowerName
        }
        let action = switch kind {
        case .pickup:
            isBorrower ? "Pick up from \(other)" : "\(other) picks up"
        case .return:
            isBorrower ? "Return to \(other)" : "\(other) returns"
        case .credit:
            loan.toolName
        }
        if loan.pickupAddress.isEmpty { return action }
        return "\(action) · \(loan.pickupAddress)"
    }

    private func scheduleUnchanged(
        _ data: [String: Any],
        title: String,
        detail: String,
        occursAt: Date,
        address: String,
        loanStatus: String,
        role: String,
        cancelled: Bool
    ) -> Bool {
        guard sameText(data["title"], title),
              sameText(data["detail"], detail),
              sameText(data["address"], address),
              sameText(data["loanStatus"], loanStatus),
              sameText(data["role"], role),
              let previous = FirestoreModels.date(data["occursAt"]),
              abs(previous.timeIntervalSince(occursAt)) <= 60 else {
            return false
        }
        let cleared = data["activityCleared"] as? Bool ?? false
        if cancelled { return cleared }
        return true
    }

    private func sameText(_ value: Any?, _ expected: String) -> Bool {
        (stringValue(value) ?? "") == expected
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
                "Firestore blocked this save. In Firebase Console → Firestore → Rules, allow signed-in users to read and write their own users/{uid} document, walletTransactions, and scheduleEvents."
            )
        }
        return error
    }
}
