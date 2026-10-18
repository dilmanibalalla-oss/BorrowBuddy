//
//  FirebaseBootstrap.swift
//  BorrowBuddy
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configure() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else {
            isConfigured = true
            return
        }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            assertionFailure("Missing GoogleService-Info.plist — download it from Firebase Console for com.toolpool.BorrowBuddy.")
            isConfigured = false
            return
        }
        FirebaseApp.configure()
        isConfigured = true
        #endif
    }
}
