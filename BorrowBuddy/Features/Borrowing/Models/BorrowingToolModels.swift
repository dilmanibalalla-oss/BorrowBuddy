//
//  BorrowingToolModels.swift
//  BorrowBuddy
//
//  Core borrowing domain types referenced by repositories and views.
//

import CoreLocation
import FirebaseFirestore
import Foundation
import MapKit

struct BorrowingTool: Identifiable, Equatable, Hashable {
    let id: String
    let ownerID: String
    let ownerName: String
    let ownerRating: Double
    let ownerLoanCount: Int
    let name: String
    let category: String
    let condition: String
    let details: String
    let dailyCredits: Int
    let depositCredits: Int
    let latitude: Double
    let longitude: Double
    let pickupAddress: String
    let imageURL: String?
    let isHighValue: Bool
    let estimatedValue: Int
    var photoData: Data?
    var listingStatus: String
    var createdAt: Date? = nil

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static let demo = BorrowingTool(
        id: "demo-drill",
        ownerID: "demo-owner",
        ownerName: "Alex Rivera",
        ownerRating: 4.8,
        ownerLoanCount: 12,
        name: "Cordless Drill",
        category: "Power Tools",
        condition: "Good",
        details: "18V kit with two batteries",
        dailyCredits: 8,
        depositCredits: 20,
        latitude: 43.6532,
        longitude: -79.3832,
        pickupAddress: "12 Maple Ave",
        imageURL: nil,
        isHighValue: false,
        estimatedValue: 120,
        photoData: nil,
        listingStatus: "available"
    )

    static let unnamed = BorrowingTool(
        id: "",
        ownerID: "",
        ownerName: "",
        ownerRating: 0,
        ownerLoanCount: 0,
        name: "Tool",
        category: "",
        condition: "",
        details: "",
        dailyCredits: 0,
        depositCredits: 0,
        latitude: 0,
        longitude: 0,
        pickupAddress: "",
        imageURL: nil,
        isHighValue: false,
        estimatedValue: 0,
        photoData: nil,
        listingStatus: "reserved"
    )
}

struct ReservationQuote: Equatable, Hashable {
    var pickupAt: Date
    var returnAt: Date
    var rentalCredits: Int
    var serviceCredits: Int
    var depositCredits: Int

    var totalHold: Int {
        rentalCredits + serviceCredits + depositCredits
    }

    static func make(for tool: BorrowingTool, pickupAt: Date? = nil, days: Int = 2) -> ReservationQuote {
        let calendar = Calendar.current
        let start = pickupAt
            ?? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            ?? Date().addingTimeInterval(86_400)
        let end = calendar.date(byAdding: .day, value: max(days, 1), to: start) ?? start.addingTimeInterval(86_400)
        let rental = tool.dailyCredits * max(days, 1)
        return ReservationQuote(
            pickupAt: start,
            returnAt: end,
            rentalCredits: rental,
            serviceCredits: 2,
            depositCredits: tool.depositCredits
        )
    }
}

enum ReservationStatus: String, Codable, Equatable {
    case pending
    case active
    case cancelled
    case completed
}

struct LoanRating: Equatable, Hashable {
    let stars: Int
    let comment: String
}

struct LoanNote: Identifiable, Equatable {
    let id: String
    let authorID: String
    let message: String
    let createdAt: Date
}

struct ReservationRecord: Identifiable, Equatable, Hashable {
    let id: String
    let receipt: String
    let toolID: String
    let toolName: String
    let ownerID: String
    let borrowerID: String
    let pickupAt: Date
    let returnAt: Date
    let totalHold: Int
    var status: ReservationStatus
    let requestedAt: Date
    var ownerAccepted: Bool = false
    var lifecycleStage: LoanLifecycleStage = .pending
    var acknowledgements: [String] = []
    var pickupAddress: String = ""
    var ownerName: String = ""
    var borrowerName: String = ""
    var rentalCredits: Int = 0
    var serviceCredits: Int = 0
    var depositCredits: Int = 0
    var toolSnapshot: BorrowingTool = .unnamed
    var arrivalAt: Date? = nil
    var arrivalAccuracy: Double? = nil
    var reviewFlag: String? = nil
    var settledCharge: Int? = nil
    var activatedAt: Date? = nil
    var submittedForReviewAt: Date? = nil
    var completedAt: Date? = nil
    var extensionRequestedAt: Date? = nil
    var extensionCredits: Int = 0

    var isOpen: Bool {
        status == .pending || status == .active
    }

    var quote: ReservationQuote {
        ReservationQuote(
            pickupAt: pickupAt,
            returnAt: returnAt,
            rentalCredits: rentalCredits,
            serviceCredits: serviceCredits,
            depositCredits: depositCredits
        )
    }

    var receiptOwnerCredits: Int { rentalCredits }
    var receiptServiceCredits: Int { serviceCredits }
    var receiptRefund: Int { settledCharge == nil ? depositCredits : max(0, totalHold - (settledCharge ?? 0)) }
}

enum FirestoreModels {
    static func loan(id: String, data: [String: Any]) -> ReservationRecord? {
        guard let receipt = data["receipt"] as? String,
              let toolID = data["toolId"] as? String,
              let toolName = data["toolName"] as? String,
              let ownerID = data["ownerId"] as? String,
              let borrowerID = data["borrowerId"] as? String else {
            return nil
        }

        let pickupAt = (data["pickupAt"] as? Timestamp)?.dateValue()
            ?? data["pickupAt"] as? Date
            ?? Date()
        let returnAt = (data["returnAt"] as? Timestamp)?.dateValue()
            ?? data["returnAt"] as? Date
            ?? Date()
        let requestedAt = (data["requestedAt"] as? Timestamp)?.dateValue()
            ?? data["requestedAt"] as? Date
            ?? Date()
        let statusRaw = data["status"] as? String ?? "pending"
        let stageRaw = data["lifecycleStage"] as? String ?? "pending"
        let geo = data["returnLocation"] as? GeoPoint
        let dailyCredits = (data["dailyCredits"] as? NSNumber)?.intValue ?? 0
        let depositCredits = (data["depositCredits"] as? NSNumber)?.intValue ?? 0

        return ReservationRecord(
            id: id,
            receipt: receipt,
            toolID: toolID,
            toolName: toolName,
            ownerID: ownerID,
            borrowerID: borrowerID,
            pickupAt: pickupAt,
            returnAt: returnAt,
            totalHold: (data["totalHold"] as? NSNumber)?.intValue ?? 0,
            status: ReservationStatus(rawValue: statusRaw) ?? .pending,
            requestedAt: requestedAt,
            ownerAccepted: data["ownerAccepted"] as? Bool ?? false,
            lifecycleStage: LoanLifecycleStage(rawValue: stageRaw) ?? .pending,
            acknowledgements: data["acknowledgements"] as? [String] ?? [],
            pickupAddress: data["pickupAddress"] as? String ?? "",
            ownerName: data["ownerName"] as? String ?? "",
            borrowerName: data["borrowerName"] as? String ?? "",
            rentalCredits: (data["rentalCredits"] as? NSNumber)?.intValue ?? 0,
            serviceCredits: (data["serviceCredits"] as? NSNumber)?.intValue ?? 0,
            depositCredits: depositCredits,
            toolSnapshot: BorrowingTool(
                id: toolID,
                ownerID: ownerID,
                ownerName: data["ownerName"] as? String ?? "",
                ownerRating: 0,
                ownerLoanCount: 0,
                name: toolName,
                category: data["category"] as? String ?? "",
                condition: data["condition"] as? String ?? "",
                details: "",
                dailyCredits: dailyCredits,
                depositCredits: depositCredits,
                latitude: geo?.latitude ?? 0,
                longitude: geo?.longitude ?? 0,
                pickupAddress: data["pickupAddress"] as? String ?? "",
                imageURL: data["imageURL"] as? String,
                isHighValue: false,
                estimatedValue: 0,
                photoData: photoData(data["photoData"]),
                listingStatus: "reserved"
            ),
            arrivalAt: date(data["arrivalAt"]),
            arrivalAccuracy: (data["arrivalAccuracy"] as? NSNumber)?.doubleValue,
            reviewFlag: data["reviewFlag"] as? String,
            settledCharge: (data["loanCharge"] as? NSNumber)?.intValue,
            activatedAt: date(data["activatedAt"]),
            submittedForReviewAt: date(data["submittedForReviewAt"]),
            completedAt: date(data["completedAt"]),
            extensionRequestedAt: date(data["extensionRequestedAt"]),
            extensionCredits: (data["extensionCredits"] as? NSNumber)?.intValue ?? 0
        )
    }

    static func date(_ value: Any?) -> Date? {
        if let timestamp = value as? Timestamp { return timestamp.dateValue() }
        return value as? Date
    }

    static func photoData(_ value: Any?) -> Data? {
        let bytes: Data?
        if let data = value as? Data {
            bytes = data
        } else if let data = value as? NSData {
            bytes = data as Data
        } else if let base64 = value as? String {
            bytes = Data(base64Encoded: base64)
        } else {
            bytes = nil
        }
        guard let bytes, !bytes.isEmpty else { return nil }
        return bytes
    }
}
