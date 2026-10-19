#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirebaseLoanLifecycleRepository: LoanLifecycleRepository {
    private let database = Firestore.firestore()

    func restoreEvidence(reservationID: String) async throws -> String? {
        let store = EvidencePhotoStore()
        for phase in [EvidencePhase.pickup, .return] {
            let snapshot = try await database.collection("reservations").document(reservationID)
                .collection("evidence").document(phase.rawValue).collection("photos").getDocuments()
            for doc in snapshot.documents {
                let data = doc.data()
                guard let angle = EvidenceAngle(rawValue: doc.documentID),
                      let jpeg = data["jpeg"] as? Data, let capturedAt = data["capturedAt"] as? Timestamp else { continue }
                let photo = EvidencePhoto(id: "\(phase.rawValue)-\(angle.rawValue)", phase: phase, angle: angle,
                                          fileName: "\(phase.rawValue)-\(angle.rawValue).jpg", capturedAt: capturedAt.dateValue())
                try store.restore(data: jpeg, photo: photo, reservationID: reservationID)
            }
        }
        return try await database.collection("reservations").document(reservationID)
            .collection("evidence").document("pickup").getDocument().data()?["conditionNote"] as? String
    }

    func setStage(reservationID: String, stage: LoanLifecycleStage) async throws {
        guard Auth.auth().currentUser != nil else {
            throw FirebaseBorrowingError.signInRequired
        }
        var data: [String: Any] = [
            "lifecycleStage": stage.rawValue,
            "status": reservationStatus(for: stage),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        data[timestampField(for: stage)] = FieldValue.serverTimestamp()
        try await database.collection("reservations").document(reservationID).updateData(data)
    }

    func saveEvidence(
        reservationID: String,
        phase: EvidencePhase,
        photos: [EvidencePhoto],
        conditionNote: String
    ) async throws {
        guard Auth.auth().currentUser != nil else {
            throw FirebaseBorrowingError.signInRequired
        }
        let capturedAt = Dictionary(uniqueKeysWithValues: photos.map {
            ($0.angle.rawValue, Timestamp(date: $0.capturedAt))
        })
        guard photos.count == 8, Set(photos.map(\.angle)).count == 8 else {
            throw LoanLifecycleViewModelError.missingPhotoPairs
        }
        let reference = database.collection("reservations")
            .document(reservationID)
            .collection("evidence")
            .document(phase.rawValue)
        let batch = database.batch()
        batch.setData([
                "phase": phase.rawValue,
                "count": photos.count,
                "angles": photos.map { $0.angle.rawValue },
                "capturedAt": capturedAt,
                "conditionNote": conditionNote,
                "storage": "private-firestore",
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: reference, merge: true)
        let store = EvidencePhotoStore()
        for photo in photos {
            batch.setData([
                "jpeg": try store.data(for: photo, reservationID: reservationID),
                "capturedAt": Timestamp(date: photo.capturedAt), "angle": photo.angle.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: reference.collection("photos").document(photo.angle.rawValue))
        }
        try await batch.commit()
    }

    func saveConditionAnalysis(
        reservationID: String,
        results: [ConditionComparisonResult]
    ) async throws {
        guard Auth.auth().currentUser != nil else {
            throw FirebaseBorrowingError.signInRequired
        }
        let scores = Dictionary(uniqueKeysWithValues: results.map {
            ($0.angle.rawValue, Double($0.distance))
        })
        let reviewAngles = results
            .filter { $0.verdict == .review }
            .map { $0.angle.rawValue }

        try await database.collection("reservations")
            .document(reservationID)
            .collection("evidence")
            .document(EvidencePhase.return.rawValue)
            .setData([
                "comparisonScores": scores,
                "reviewAngles": reviewAngles,
                "analysisSDK": "Apple Vision",
                "analyzedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    func completeLoan(reservationID: String, settlement: LoanSettlement) async throws {
        guard let ownerID = Auth.auth().currentUser?.uid else {
            throw FirebaseBorrowingError.signInRequired
        }
        let reservationReference = database.collection("reservations").document(reservationID)
        let ownerReference = database.collection("users").document(ownerID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction({ transaction, errorPointer in
                do {
                    let reservationSnapshot = try transaction.getDocument(reservationReference)
                    guard let reservation = reservationSnapshot.data(),
                          let loan = FirestoreModels.loan(id: reservationID, data: reservation),
                          loan.ownerID == ownerID else {
                        throw CommunityError.wrongRole
                    }
                    guard loan.lifecycleStage == .awaitingReview, loan.reviewFlag == nil else { throw CommunityError.invalidStep }
                    let borrowerReference = self.database.collection("users").document(loan.borrowerID)
                    let toolReference = self.database.collection("tools").document(loan.toolID)
                    let ownerSnapshot = try transaction.getDocument(ownerReference)
                    _ = try transaction.getDocument(toolReference)

                    transaction.updateData([
                        "status": "completed",
                        "lifecycleStage": LoanLifecycleStage.completed.rawValue,
                        "loanCharge": loan.rentalCredits + loan.serviceCredits,
                        "depositRefund": loan.depositCredits,
                        "completedAt": FieldValue.serverTimestamp(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: reservationReference)

                    transaction.updateData([
                        "creditBalance": FieldValue.increment(Int64(loan.depositCredits)),
                        "creditHeld": FieldValue.increment(Int64(-loan.totalHold)),
                        "lastSettledReservationId": reservationID,
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: borrowerReference)
                    transaction.updateData([
                        "creditBalance": self.number(ownerSnapshot.data()?["creditBalance"]).intValue + loan.rentalCredits,
                        "lastIncomeReservationId": reservationID, "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: ownerReference)
                    transaction.updateData([
                        "status": "available", "reservationId": "", "updatedAt": FieldValue.serverTimestamp()
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

    private func reservationStatus(for stage: LoanLifecycleStage) -> String {
        switch stage {
        case .pending, .pickupInspection:
            "pending"
        case .active, .returnTransit, .returnInspection, .awaitingReview:
            "active"
        case .completed:
            "completed"
        }
    }

    private func timestampField(for stage: LoanLifecycleStage) -> String {
        switch stage {
        case .pending: "pendingAt"
        case .pickupInspection: "pickupInspectionStartedAt"
        case .active: "activatedAt"
        case .returnTransit: "returnStartedAt"
        case .returnInspection: "returnInspectionStartedAt"
        case .awaitingReview: "submittedForReviewAt"
        case .completed: "completedAt"
        }
    }

    private func number(_ value: Any?) -> NSNumber {
        value as? NSNumber ?? 0
    }
}
#endif
