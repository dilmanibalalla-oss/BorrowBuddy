#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirebaseCommunityRepository: CommunityRepository {
    private let database = Firestore.firestore()

    func respond(reservationID: String, accepted: Bool) async throws {
        let userID = try currentUserID()
        let reference = database.collection("reservations").document(reservationID)
        let snapshot = try await reference.getDocument()
        guard let data = snapshot.data(), data["ownerId"] as? String == userID else {
            throw CommunityError.wrongRole
        }
        var update: [String: Any] = [
            "ownerAccepted": accepted,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if !accepted {
            update["status"] = ReservationStatus.cancelled.rawValue
        }
        try await reference.updateData(update)
    }

    func cancel(reservationID: String) async throws {
        let userID = try currentUserID()
        let reference = database.collection("reservations").document(reservationID)
        let snapshot = try await reference.getDocument()
        guard let data = snapshot.data() else {
            throw CommunityError.invalidInput("This reservation no longer exists.")
        }
        let ownerID = data["ownerId"] as? String
        let borrowerID = data["borrowerId"] as? String
        guard userID == ownerID || userID == borrowerID else { throw CommunityError.wrongRole }
        try await reference.updateData([
            "status": ReservationStatus.cancelled.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func saveAddress(street: String, unit: String, postalCode: String, latitude: Double, longitude: Double) async throws {
        let userID = try currentUserID()
        let reference = database.collection("users").document(userID)
        let snapshot = try await reference.getDocument()
        let address = ["street": street, "unit": unit, "postalCode": postalCode]
        var payload: [String: Any] = [
            "address": address,
            "shedLocation": [
                "street": street,
                "unit": unit,
                "postalCode": postalCode,
                "latitude": latitude,
                "longitude": longitude
            ],
            "location": GeoPoint(latitude: latitude, longitude: longitude),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if snapshot.data()?["creditBalance"] == nil {
            payload["creditBalance"] = AccountSummary.newAccountCredits
            payload["creditHeld"] = 0
            if !snapshot.exists {
                payload["createdAt"] = FieldValue.serverTimestamp()
            }
        }
        try await reference.setData(payload, merge: true)
    }

    func acknowledgePickup(reservationID: String) async throws {
        let userID = try currentUserID()
        let reference = database.collection("reservations").document(reservationID)
        let snapshot = try await reference.getDocument()
        guard let data = snapshot.data() else {
            throw CommunityError.invalidInput("This reservation no longer exists.")
        }
        let ownerID = data["ownerId"] as? String ?? ""
        let borrowerID = data["borrowerId"] as? String ?? ""
        guard userID == ownerID || userID == borrowerID else { throw CommunityError.wrongRole }

        var acknowledgements = data["acknowledgements"] as? [String] ?? []
        if !acknowledgements.contains(userID) {
            acknowledgements.append(userID)
        }
        var update: [String: Any] = [
            "acknowledgements": acknowledgements,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        // The borrower has already uploaded the 8 baseline photos before this acknowledgement.
        // Activating here opens the rental so return and settlement can continue.
        if acknowledgements.contains(borrowerID) && data["status"] as? String != ReservationStatus.completed.rawValue {
            update["status"] = ReservationStatus.active.rawValue
            update["lifecycleStage"] = LoanLifecycleStage.active.rawValue
            if data["activatedAt"] == nil {
                update["activatedAt"] = FieldValue.serverTimestamp()
            }
        }
        try await reference.updateData(update)
    }

    func recordArrival(reservationID: String, accuracy: Double) async throws {
        _ = try currentUserID()
        try await database.collection("reservations").document(reservationID).updateData([
            "arrivalAt": FieldValue.serverTimestamp(),
            "arrivalAccuracy": accuracy,
            "lifecycleStage": LoanLifecycleStage.returnInspection.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func flagReturn(reservationID: String, reason: String) async throws {
        _ = try currentUserID()
        try await database.collection("reservations").document(reservationID).updateData([
            "reviewFlag": reason,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func myRating(reservationID: String) async throws -> LoanRating? {
        let userID = try currentUserID()
        let snapshot = try await database.collection("users").document(userID)
            .collection("ratings").document(reservationID).getDocument()
        guard let data = snapshot.data() else { return nil }
        return LoanRating(
            stars: (data["stars"] as? NSNumber)?.intValue ?? 0,
            comment: data["comment"] as? String ?? ""
        )
    }

    func submitRating(reservationID: String, rating: LoanRating) async throws {
        let userID = try currentUserID()
        try await database.collection("users").document(userID)
            .collection("ratings").document(reservationID)
            .setData([
                "stars": rating.stars,
                "comment": rating.comment,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func requestExtension(reservationID: String, returnAt: Date) async throws {
        _ = try currentUserID()
        try await database.collection("reservations").document(reservationID).updateData([
            "extensionRequestedAt": Timestamp(date: returnAt),
            "extensionCredits": 0,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func respondToExtension(reservationID: String, accepted: Bool) async throws {
        let userID = try currentUserID()
        let reference = database.collection("reservations").document(reservationID)
        let snapshot = try await reference.getDocument()
        guard let data = snapshot.data(), data["ownerId"] as? String == userID else {
            throw CommunityError.wrongRole
        }
        var update: [String: Any] = [
            "extensionRequestedAt": FieldValue.delete(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if accepted, let proposed = FirestoreModels.date(data["extensionRequestedAt"]) {
            update["returnAt"] = Timestamp(date: proposed)
        }
        try await reference.updateData(update)
    }

    func loanNotes(reservationID: String) async throws -> [LoanNote] {
        _ = try currentUserID()
        let snapshot = try await database.collection("reservations").document(reservationID)
            .collection("notes")
            .order(by: "createdAt")
            .limit(to: 50)
            .getDocuments()
        return snapshot.documents.compactMap { document in
            let data = document.data()
            guard let message = data["message"] as? String else { return nil }
            return LoanNote(
                id: document.documentID,
                authorID: data["authorId"] as? String ?? "",
                message: message,
                createdAt: FirestoreModels.date(data["createdAt"]) ?? Date()
            )
        }
    }

    func postLoanNote(reservationID: String, message: String) async throws {
        let userID = try currentUserID()
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 500 else {
            throw CommunityError.invalidInput("Write a note of 500 characters or fewer.")
        }
        try await database.collection("reservations").document(reservationID)
            .collection("notes").addDocument(data: [
                "authorId": userID,
                "message": trimmed,
                "createdAt": FieldValue.serverTimestamp()
            ])
    }

    private func currentUserID() throws -> String {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw CommunityError.signInRequired
        }
        return userID
    }
}
#endif
