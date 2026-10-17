//
//  FirebaseBootstrap.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-18.
//

import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAppCheck)
import FirebaseAppCheck
#endif

enum FirebaseBootstrap {
    private(set) static var isConfigured = false

    static func configure() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil,
              Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            isConfigured = FirebaseApp.app() != nil
            return
        }
        #if canImport(FirebaseAppCheck)
        #if DEBUG
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        #else
        AppCheck.setAppCheckProviderFactory(BorrowBuddyAppCheckFactory())
        #endif
        #endif
        FirebaseApp.configure()
        isConfigured = true
        #endif
    }
}
#if canImport(FirebaseAppCheck)
final class BorrowBuddyAppCheckFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        if #available(iOS 14.0, *) { return AppAttestProvider(app: app) }
        return DeviceCheckProvider(app: app)
    }
}
#endif
