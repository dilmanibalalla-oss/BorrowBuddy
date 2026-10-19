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

        var data: [String: Any] = [
            "shedLocation": location.dictionary
        ]
        if let displayName = Auth.auth().currentUser?.displayName {
            data["displayName"] = displayName
        }
        if let email = Auth.auth().currentUser?.email {
            data["email"] = email
        }

        try await db.collection("users").document(uid).setData(data, merge: true)
    }
}
