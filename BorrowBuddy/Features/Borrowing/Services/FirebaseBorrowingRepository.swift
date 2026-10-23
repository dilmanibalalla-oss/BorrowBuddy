#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
import Foundation

enum FirebaseBorrowingError: LocalizedError {
    case signInRequired
    case profileMissing
    case toolUnavailable
    case unavailableDates
    case insufficientCredits

    var errorDescription: String? {
        switch self {
        case .signInRequired:
            "Sign in before continuing."
        case .profileMissing:
            "Create your BorrowBuddy profile first."
        case .toolUnavailable:
            "This tool is no longer available."
        case .unavailableDates:
            "Those loan dates are no longer available."
        case .insufficientCredits:
            "You do not have enough LendCredits."
        }
    }
}

final class FirebaseBorrowingRepository: BorrowingRepository {
    private let database = Firestore.firestore()

    func fetchNearbyTools() async throws -> [BorrowingTool] {
        _ = try currentUserID()
        let snapshot = try await database.collection("tools")
            .whereField("status", isEqualTo: "available")
            .limit(to: 30)
            .getDocuments(source: .server)
        let finishedToolIDs = await toolIDsWithCompletedLoans()
        return snapshot.documents.compactMap(makeTool).filter { !finishedToolIDs.contains($0.id) }
    }

    /// Loans completed before the tool status was updated may still be marked available.
    private func toolIDsWithCompletedLoans() async -> Set<String> {
        do {
            let snapshot = try await database.collection("reservations")
                .whereField("status", isEqualTo: "completed")
                .limit(to: 200)
                .getDocuments(source: .server)
            return Set(snapshot.documents.compactMap { $0.data()["toolId"] as? String })
        } catch {
            return []
        }
    }

    func addTool(_ tool: BorrowingTool) async throws -> String {
        let userID = try currentUserID()
        let reference = database.collection("tools").document()
        var data = toolData(tool)
        data["ownerId"] = userID
        data["status"] = "available"
        data["createdAt"] = FieldValue.serverTimestamp()
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await reference.setData(data)
        return reference.documentID
    }

    func updateTool(_ tool: BorrowingTool) async throws {
        _ = try currentUserID()
        var data = toolData(tool)
        data.removeValue(forKey: "ownerId")
        data["updatedAt"] = FieldValue.serverTimestamp()
        try await database.collection("tools").document(tool.id).setData(data, merge: true)
    }

    func deleteTool(id: String) async throws {
        _ = try currentUserID()
        try await database.collection("tools").document(id).updateData([
            "status": "removed", "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func createReservation(tool: BorrowingTool, quote: ReservationQuote) async throws -> ReservationRecord {
        let borrowerID = try currentUserID()
        guard quote.pickupAt > Date(), quote.returnAt > quote.pickupAt,
              quote.returnAt.timeIntervalSince(quote.pickupAt) <= 14 * 86400 else {
            throw CommunityError.invalidInput("Choose a future loan window of at most 14 days.")
        }

        let reservationReference = database.collection("reservations").document()
        let receipt = "LC-\(reservationReference.documentID.prefix(5).uppercased())"

        try await runReservationTransaction(
            reservationReference: reservationReference,
            borrowerID: borrowerID,
            receipt: receipt,
            tool: tool,
            quote: quote
        )

        let snapshot = try await reservationReference.getDocument()
        guard let data = snapshot.data(), let loan = FirestoreModels.loan(id: snapshot.documentID, data: data) else {
            throw FirebaseBorrowingError.profileMissing
        }
        return loan
    }

    func fetchMyLoans() async throws -> [ReservationRecord] {
        let userID = try currentUserID()
        async let borrowed = database.collection("reservations")
            .whereField("borrowerId", isEqualTo: userID)
            .limit(to: 40)
            .getDocuments()
        async let owned = database.collection("reservations")
            .whereField("ownerId", isEqualTo: userID)
            .limit(to: 40)
            .getDocuments()
        let snapshots = try await borrowed.documents + owned.documents
        var seen = Set<String>()
        return snapshots.compactMap { document -> ReservationRecord? in
            guard seen.insert(document.documentID).inserted else { return nil }
            return FirestoreModels.loan(id: document.documentID, data: document.data())
        }
        .sorted { $0.requestedAt > $1.requestedAt }
    }

    func fetchReservation(id: String) async throws -> ReservationRecord {
        _ = try currentUserID()
        // Approval refresh must use the server, not an initial cached listener value.
        let snapshot = try await database.collection("reservations").document(id).getDocument(source: .server)
        guard let data = snapshot.data(), let loan = FirestoreModels.loan(id: snapshot.documentID, data: data) else {
            throw CommunityError.invalidInput("This reservation no longer exists or has incomplete data.")
        }
        return loan
    }

    func reservationUpdates(id: String) -> AsyncThrowingStream<ReservationRecord, Error> {
        AsyncThrowingStream { continuation in
            let listener = database.collection("reservations").document(id).addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                guard let snapshot, let data = snapshot.data(),
                      let loan = FirestoreModels.loan(id: snapshot.documentID, data: data) else {
                    return
                }
                continuation.yield(loan)
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    private func runReservationTransaction(
        reservationReference: DocumentReference,
        borrowerID: String,
        receipt: String,
        tool: BorrowingTool,
        quote: ReservationQuote
    ) async throws {
        let toolReference = database.collection("tools").document(tool.id)
        let borrowerReference = database.collection("users").document(borrowerID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer in
                do {
                    let toolSnapshot = try transaction.getDocument(toolReference)
                    let borrowerSnapshot = try transaction.getDocument(borrowerReference)
                    guard let toolData = toolSnapshot.data(),
                          toolData["status"] as? String == "available" else {
                        throw FirebaseBorrowingError.toolUnavailable
                    }
                    guard let borrowerData = borrowerSnapshot.data() else {
                        throw FirebaseBorrowingError.profileMissing
                    }
                    guard toolData["ownerId"] as? String != borrowerID else { throw CommunityError.wrongRole }
                    guard borrowerData["borrowingBlocked"] as? Bool != true else { throw CommunityError.blocked }

                    let balance = self.number(borrowerData["creditBalance"]).intValue
                    let held = self.number(borrowerData["creditHeld"]).intValue
                    guard balance >= quote.totalHold else {
                        throw FirebaseBorrowingError.insufficientCredits
                    }

                    transaction.updateData([
                        "creditBalance": balance - quote.totalHold,
                        "creditHeld": held + quote.totalHold,
                        "lastReservationId": reservationReference.documentID,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: borrowerReference)

                    transaction.setData([
                        "receipt": receipt,
                        "toolId": tool.id,
                        "toolName": toolData["name"] as? String ?? tool.name,
                        "ownerId": toolData["ownerId"] as? String ?? tool.ownerID,
                        "ownerName": toolData["ownerName"] as? String ?? tool.ownerName,
                        "borrowerId": borrowerID,
                        "borrowerName": borrowerData["displayName"] as? String ?? "Neighbor",
                        "dailyCredits": self.number(toolData["dailyCredits"]).intValue,
                        "pickupAddress": toolData["pickupAddress"] as? String ?? tool.pickupAddress,
                        "returnLocation": toolData["location"] as? GeoPoint ?? GeoPoint(latitude: tool.latitude, longitude: tool.longitude),
                        "pickupAt": Timestamp(date: quote.pickupAt),
                        "returnAt": Timestamp(date: quote.returnAt),
                        "rentalCredits": quote.rentalCredits,
                        "serviceCredits": quote.serviceCredits,
                        "depositCredits": quote.depositCredits,
                        "totalHold": quote.totalHold,
                        "status": "pending",
                        "lifecycleStage": "pending",
                        "ownerAccepted": false,
                        "acknowledgements": [],
                        "requestedAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: reservationReference)
                    transaction.updateData([
                        "status": "reserved", "reservationId": reservationReference.documentID,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: toolReference)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func makeTool(_ document: QueryDocumentSnapshot) -> BorrowingTool? {
        let data = document.data()
        guard let ownerID = data["ownerId"] as? String,
              let ownerName = data["ownerName"] as? String,
              let name = data["name"] as? String,
              let category = data["category"] as? String,
              let location = data["location"] as? GeoPoint else {
            return nil
        }
        return BorrowingTool(
            id: document.documentID,
            ownerID: ownerID,
            ownerName: ownerName,
            ownerRating: number(data["ownerRating"]).doubleValue,
            ownerLoanCount: number(data["ownerLoanCount"]).intValue,
            name: name,
            category: category,
            condition: data["condition"] as? String ?? "Good",
            details: data["details"] as? String ?? "",
            dailyCredits: number(data["dailyCredits"]).intValue,
            depositCredits: number(data["depositCredits"]).intValue,
            latitude: location.latitude,
            longitude: location.longitude,
            pickupAddress: data["pickupAddress"] as? String ?? "",
            imageURL: data["imageURL"] as? String,
            isHighValue: data["isHighValue"] as? Bool ?? false,
            estimatedValue: number(data["estimatedValue"]).intValue,
            photoData: data["photoData"] as? Data,
            listingStatus: data["status"] as? String ?? "available"
        )
    }

    private func toolData(_ tool: BorrowingTool) -> [String: Any] {
        [
            "ownerId": tool.ownerID,
            "ownerName": tool.ownerName,
            "ownerRating": tool.ownerRating,
            "ownerLoanCount": tool.ownerLoanCount,
            "name": tool.name,
            "category": tool.category,
            "condition": tool.condition,
            "details": tool.details,
            "dailyCredits": tool.dailyCredits,
            "depositCredits": tool.depositCredits,
            "location": GeoPoint(latitude: tool.latitude, longitude: tool.longitude),
            "pickupAddress": tool.pickupAddress,
            "imageURL": tool.imageURL ?? NSNull(),
            "photoData": tool.photoData ?? Data(),
            "isHighValue": tool.isHighValue,
            "estimatedValue": tool.estimatedValue
        ]
    }

    private func currentUserID() throws -> String {
        guard let userID = Auth.auth().currentUser?.uid else {
            throw FirebaseBorrowingError.signInRequired
        }
        return userID
    }

    private func number(_ value: Any?) -> NSNumber {
        value as? NSNumber ?? 0
    }
}
#endif
