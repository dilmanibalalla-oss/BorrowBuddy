//
//  AccountModels.swift
//  BorrowBuddy
//

import Foundation

struct AccountSummary: Equatable {
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
    let id: String
    let title: String
    let detail: String
    let credits: Int
}

struct CreditPack: Identifiable, Equatable {
    let id: String
    let title: String
    let credits: Int
    let price: Decimal

    static let starter = CreditPack(id: "starter", title: "Starter Pack", credits: 50, price: 5)
    static let builder = CreditPack(id: "builder", title: "Builder Bundle", credits: 150, price: 12)
}

enum AccountDestination: Hashable {
    case editProfile
    case notifications
    case paymentMethods
    case wallet
    case creditTopUp
    case loanProtection
}
