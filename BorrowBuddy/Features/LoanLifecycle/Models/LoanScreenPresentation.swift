import Foundation

enum LoanScreenPresentation: Equatable {
    case pending, pickup, baseline, active, returning, returnPhotos, review, completed

    static func screen(for loan: ReservationRecord, userID: String?, baselineCount: Int) -> Self {
        if loan.status == .completed { return .completed }
        if !loan.isOpen { return .pending }
        switch loan.lifecycleStage {
        case .pending: return .pending
        case .pickupInspection:
            // Legacy/incomplete records must return to acceptance, not an inert pickup screen.
            guard loan.status == .pending, loan.ownerAccepted else { return .pending }
            if baselineCount == EvidenceAngle.allCases.count { return .baseline }
            return userID == loan.borrowerID ? .pickup : .pending
        case .active: return .active
        case .returnTransit: return userID == loan.borrowerID ? .returning : .active
        case .returnInspection: return userID == loan.borrowerID ? .returnPhotos : .active
        case .awaitingReview: return .review
        case .completed: return .completed
        }
    }
}
