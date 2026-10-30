import Foundation

enum LoanLifecycleStage: String, Codable {
    case pending
    case pickupInspection
    case active
    case returnTransit
    case returnInspection
    case awaitingReview
    case completed
}

enum EvidencePhase: String, Codable {
    case pickup
    case `return`
}

enum PickupInspectionBlocker: Equatable {
    case missingReservation, wrongAccount, wrongStage, awaitingOwner, incompleteChecklist
}

enum PickupInspectionEligibility {
    static func blocker(for loan: ReservationRecord?, userID: String?, kitConfirmed: Bool,
                        wearReviewed: Bool) -> PickupInspectionBlocker? {
        guard let loan, !loan.id.isEmpty, !loan.toolID.isEmpty,
              !loan.ownerID.isEmpty, !loan.borrowerID.isEmpty else { return .missingReservation }
        guard userID == loan.borrowerID else { return .wrongAccount }
        guard loan.status == .pending, loan.lifecycleStage == .pending || loan.lifecycleStage == .pickupInspection else {
            return .wrongStage
        }
        guard loan.ownerAccepted else { return .awaitingOwner }
        guard kitConfirmed && wearReviewed else { return .incompleteChecklist }
        return nil
    }
}

enum EvidenceAngle: String, CaseIterable, Codable, Identifiable {
    case front
    case left
    case right
    case rear
    case serial
    case battery
    case caseView
    case wear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .caseView: "Case"
        default: rawValue.capitalized
        }
    }

    var instruction: String {
        switch self {
        case .front: "Align the full front of the tool inside the frame"
        case .left: "Align the full left side inside the frame"
        case .right: "Align the full right side inside the frame"
        case .rear: "Show the rear and handle clearly"
        case .serial: "Keep the serial label sharp and fully visible"
        case .battery: "Show the battery label and connection points"
        case .caseView: "Include the case and every included accessory"
        case .wear: "Capture existing scratches and wear points"
        }
    }
}

struct EvidencePhoto: Identifiable, Codable, Equatable {
    let id: String
    let phase: EvidencePhase
    let angle: EvidenceAngle
    let fileName: String
    let capturedAt: Date
}

enum ConditionComparisonVerdict: String, Codable, Equatable {
    case match
    case review
}

struct ConditionComparisonResult: Identifiable, Codable, Equatable {
    let angle: EvidenceAngle
    let distance: Float
    let verdict: ConditionComparisonVerdict

    var id: String { angle.rawValue }
}

enum ConditionComparisonPolicy {
    /// Vision feature-print distance is a similarity signal. It must not be treated
    /// as an automatic damage decision; borderline pairs always go to owner review.
    static let reviewThreshold: Float = 0.45

    static func verdict(
        for distance: Float,
        threshold: Float = reviewThreshold
    ) -> ConditionComparisonVerdict {
        distance <= threshold ? .match : .review
    }
}

enum LoanLifecyclePolicy {
    static func canTransition(
        from current: LoanLifecycleStage,
        to next: LoanLifecycleStage
    ) -> Bool {
        switch (current, next) {
        case (.pending, .pickupInspection),
             (.pickupInspection, .active),
             (.active, .returnTransit),
             (.returnTransit, .returnInspection),
             (.returnInspection, .awaitingReview),
             (.awaitingReview, .completed):
            true
        default:
            false
        }
    }
}

enum NonReturnStatus: String, Codable, Equatable {
    case upcoming
    case dueSoon
    case overdueGracePeriod
    case borrowingBlocked
    case escalationEligible
}

enum NonReturnPolicy {
    static let dueSoonInterval: TimeInterval = 24 * 60 * 60
    static let graceInterval: TimeInterval = 24 * 60 * 60
    static let escalationInterval: TimeInterval = 7 * 24 * 60 * 60

    static func status(returnAt: Date, now: Date) -> NonReturnStatus {
        let untilDue = returnAt.timeIntervalSince(now)
        if untilDue > dueSoonInterval { return .upcoming }
        if untilDue > 0 { return .dueSoon }

        let overdue = now.timeIntervalSince(returnAt)
        if overdue < graceInterval { return .overdueGracePeriod }
        if overdue < escalationInterval { return .borrowingBlocked }
        return .escalationEligible
    }

    static func applies(to loan: ReservationRecord, now: Date) -> Bool {
        loan.status == .active
            && loan.lifecycleStage != .awaitingReview
            && loan.lifecycleStage != .completed
            && loan.returnAt < now
    }

    struct StageNotice: Equatable {
        let status: NonReturnStatus
        let title: String
        let message: String
    }

    static func notice(for loan: ReservationRecord, now: Date) -> StageNotice? {
        guard applies(to: loan, now: now) else { return nil }
        switch status(returnAt: loan.returnAt, now: now) {
        case .overdueGracePeriod:
            return StageNotice(
                status: .overdueGracePeriod,
                title: "Overdue grace period",
                message: "Both neighbors are notified. You can message each other or agree an extension."
            )
        case .borrowingBlocked:
            return StageNotice(
                status: .borrowingBlocked,
                title: "Borrowing paused",
                message: "New borrowing is blocked while this loan stays unresolved."
            )
        case .escalationEligible:
            return StageNotice(
                status: .escalationEligible,
                title: "Support escalation",
                message: "This case is eligible for support escalation and human review."
            )
        default:
            return nil
        }
    }

    static func shouldBlockBorrowing(loans: [ReservationRecord], borrowerID: String, now: Date) -> Bool {
        loans.contains { loan in
            loan.borrowerID == borrowerID
                && notice(for: loan, now: now)?.status != .overdueGracePeriod
                && notice(for: loan, now: now) != nil
        }
    }
}

enum LoanRules {
    static func canVerifyArrival(distance: Double, accuracy: Double, age: TimeInterval) -> Bool {
        distance <= 50 && accuracy > 0 && accuracy <= 100 && age >= 0 && age < 180
    }

    static func canOpenNonReturnCase(_ loan: ReservationRecord, userID: String, now: Date) -> Bool {
        loan.ownerID == userID && loan.status == .active && now > loan.returnAt.addingTimeInterval(24 * 60 * 60)
    }
}

struct LoanSettlement: Codable, Equatable {
    let totalHold: Int
    let loanCharge: Int
    let depositRefund: Int

    var balanceChange: Int {
        depositRefund
    }
}
