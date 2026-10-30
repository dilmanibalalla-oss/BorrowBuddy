#if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseFirestore
import Foundation

final class FirebaseNonReturnCaseRepository: NonReturnCaseRepository {
    private let database = Firestore.firestore()

    func openCase(
        reservationID: String,
        toolID: String,
        borrowerID: String,
        reason: String
    ) async throws -> String {
        guard let ownerID = Auth.auth().currentUser?.uid else {
            throw FirebaseBorrowingError.signInRequired
        }
        let reference = database.collection("nonReturnCases").document(reservationID)
        if try await reference.getDocument().exists { return reference.documentID }
        let reservation = try await database.collection("reservations").document(reservationID).getDocument()
        let returnAt = FirestoreModels.date(reservation.data()?["returnAt"]) ?? Date()
        let caseStatus = NonReturnPolicy.status(returnAt: returnAt, now: Date()) == .escalationEligible
            ? NonReturnStatus.escalationEligible.rawValue
            : "open"
        try await reference.setData([
            "reservationId": reservationID,
            "toolId": toolID,
            "ownerId": ownerID,
            "borrowerId": borrowerID,
            "status": caseStatus,
            "reason": reason,
            "openedAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        return reference.documentID
    }
}
#endif
