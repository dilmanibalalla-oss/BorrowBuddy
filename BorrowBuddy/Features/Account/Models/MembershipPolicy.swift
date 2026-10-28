import CoreLocation
import Foundation

/// Rules for BorrowBuddy Pro, high-value borrowing, and the 50 m drop-off region.
/// These sit beside the existing reservation transaction and do not replace it.
enum MembershipPolicy {
    static let proWelcomeCredits = 10
    static let freeOpenBorrowLimit = 1

    static func canStartAnotherBorrow(openBorrowCount: Int, isPro: Bool) -> Bool {
        isPro || openBorrowCount < freeOpenBorrowLimit
    }

    static func canBorrowHighValueTool(identityVerified: Bool, addressConfirmed: Bool) -> Bool {
        identityVerified && addressConfirmed
    }
}

enum StoreCatalog {
    static let starterProductID = "com.toolpool.BorrowBuddy.credits.starter"
    static let builderProductID = "com.toolpool.BorrowBuddy.credits.builder"
    static let proMonthlyProductID = "com.toolpool.BorrowBuddy.pro.monthly"

    static var creditProductIDs: [String] {
        [starterProductID, builderProductID]
    }

    static var allProductIDs: [String] {
        creditProductIDs + [proMonthlyProductID]
    }

    static func credits(for productID: String) -> Int? {
        switch productID {
        case starterProductID:
            return CreditPack.starter.credits
        case builderProductID:
            return CreditPack.builder.credits
        default:
            return nil
        }
    }

    static func pack(for productID: String) -> CreditPack? {
        switch productID {
        case starterProductID:
            return .starter
        case builderProductID:
            return .builder
        default:
            return nil
        }
    }
}

enum DropOffRegionPolicy {
    static let radius: CLLocationDistance = 50

    static func shouldMonitor(_ loan: ReservationRecord, borrowerID: String?) -> Bool {
        guard let borrowerID, loan.borrowerID == borrowerID, loan.status == .active else { return false }
        switch loan.lifecycleStage {
        case .active, .returnTransit:
            return hasDropOffCoordinate(loan)
        default:
            return false
        }
    }

    static func region(for loan: ReservationRecord) -> CLCircularRegion? {
        guard hasDropOffCoordinate(loan) else { return nil }
        let region = CLCircularRegion(
            center: loan.toolSnapshot.coordinate,
            radius: radius,
            identifier: loan.id
        )
        region.notifyOnEntry = true
        region.notifyOnExit = false
        return region
    }

    private static func hasDropOffCoordinate(_ loan: ReservationRecord) -> Bool {
        let coordinate = loan.toolSnapshot.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return false }
        return coordinate.latitude != 0 || coordinate.longitude != 0
    }
}

enum ReturnReminderSchedule {
    static let dayBefore: TimeInterval = -86_400
    static let twoHoursBefore: TimeInterval = -7_200
    static let due = TimeInterval(0)
    static let overdue: TimeInterval = 60 * 60
    static let graceEnded = NonReturnPolicy.graceInterval

    static func borrowerReturnReminders(returnAt: Date) -> [(suffix: String, title: String, fireAt: Date)] {
        [
            ("return-day", "Return due tomorrow", returnAt.addingTimeInterval(dayBefore)),
            ("return-hour", "Return due in two hours", returnAt.addingTimeInterval(twoHoursBefore)),
            ("due", "Return due", returnAt.addingTimeInterval(due)),
            ("overdue", "Return overdue", returnAt.addingTimeInterval(overdue)),
            ("grace-ended", "Return grace period ended", returnAt.addingTimeInterval(graceEnded))
        ]
    }
}

enum CalendarReminderPolicy {
    static let returnDayBefore: TimeInterval = -24 * 60 * 60
    static let returnTwoHoursBefore: TimeInterval = -2 * 60 * 60
    static let listingHourBefore: TimeInterval = -3_600
}

enum LendCreditMath {
    static func balance(afterPurchase credits: Int, current balance: Int) -> Int {
        balance + credits
    }

    static func balance(afterHold hold: Int, current balance: Int) -> Int? {
        guard hold >= 0, balance >= hold else { return nil }
        return balance - hold
    }
}
