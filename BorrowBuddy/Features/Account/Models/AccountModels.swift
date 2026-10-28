//
//  AccountModels.swift
//  BorrowBuddy
//

import Foundation

struct AccountSummary: Equatable {
    /// Credits given once, the first time an account record is created.
    static let newAccountCredits = 1000

    let displayName: String
    let neighborhood: String
    let phoneNumber: String
    let creditBalance: Int
    let creditHeld: Int
    var photoData: Data? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var streetAddress: String = ""
    var unit: String = ""
    var postalCode: String = ""
    var identityVerified: Bool = false
    var addressConfirmed: Bool = false
    var isPro: Bool = false
}

struct NotificationSettings: Codable, Equatable {
    var reservationUpdates: Bool
    var pickupReminders: Bool
    var returnReminders: Bool
    var neighborhoodActivity: Bool

    static let standard = NotificationSettings(
        reservationUpdates: true,
        pickupReminders: true,
        returnReminders: true,
        neighborhoodActivity: false
    )

    var dictionary: [String: Bool] {
        [
            "reservationUpdates": reservationUpdates,
            "pickupReminders": pickupReminders,
            "returnReminders": returnReminders,
            "neighborhoodActivity": neighborhoodActivity
        ]
    }
}

struct WalletEntry: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case credit
        case pickup
        case `return`
    }

    let id: String
    let title: String
    let detail: String
    let credits: Int
    var kind: Kind = .credit
    var recordedAt: Date = .distantPast
}

struct ScheduleEvent: Identifiable, Equatable {
    let id: String
    let kind: WalletEntry.Kind
    let reservationID: String
    let title: String
    let detail: String
    let occursAt: Date
    let address: String
    let loanStatus: String

    var isUpcoming: Bool {
        occursAt >= Calendar.current.startOfDay(for: Date()) && loanStatus != ReservationStatus.completed.rawValue
    }
}

struct CreditPack: Identifiable, Equatable {
    let id: String
    let title: String
    let credits: Int
    let price: Decimal

    static let starter = CreditPack(id: "starter", title: "Starter Pack", credits: 50, price: 5)
    static let builder = CreditPack(id: "builder", title: "Builder Bundle", credits: 150, price: 12)

    var productID: String {
        switch id {
        case Self.builder.id:
            return StoreCatalog.builderProductID
        default:
            return StoreCatalog.starterProductID
        }
    }
}

enum AccountDestination: Hashable {
    case editProfile
    case notifications
    case paymentMethods
    case wallet
    case creditTopUp
    case loanProtection
    case identityVerification
}
