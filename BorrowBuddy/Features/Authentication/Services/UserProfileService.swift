//
//  UserProfileService.swift
//  BorrowBuddy
//

import FirebaseAuth
import FirebaseFirestore
import Foundation

struct ShedLocation: Equatable {
    var street: String
    var unit: String
    var postalCode: String
    var latitude: Double
    var longitude: Double

    var dictionary: [String: Any] {
        [
            "street": street,
            "unit": unit,
            "postalCode": postalCode,
            "latitude": latitude,
            "longitude": longitude,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}

protocol UserProfileService: AnyObject {
    func saveShedLocation(_ location: ShedLocation) async throws
}

final class FirestoreUserProfileService: UserProfileService {
    private let db = Firestore.firestore()

    func saveShedLocation(_ location: ShedLocation) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw CommunityError.signInRequired
        }

        let reference = db.collection("users").document(uid)
        let snapshot = try await reference.getDocument()
        var data: [String: Any] = [
            "shedLocation": location.dictionary,
            "address": [
                "street": location.street,
                "unit": location.unit,
                "postalCode": location.postalCode
            ],
            "location": GeoPoint(latitude: location.latitude, longitude: location.longitude)
        ]
        let savedName = (snapshot.data()?["displayName"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if savedName.isEmpty, let displayName = Auth.auth().currentUser?.displayName {
            data["displayName"] = displayName
        }
        if let email = Auth.auth().currentUser?.email {
            data["email"] = email
        }
        if snapshot.data()?["creditBalance"] == nil {
            data["creditBalance"] = AccountSummary.newAccountCredits
            data["creditHeld"] = 0
            if !snapshot.exists {
                data["createdAt"] = FieldValue.serverTimestamp()
            }
        }

        try await reference.setData(data, merge: true)
    }
}
