//
//  AppDelegate.swift
//  BorrowBuddy
//
//  Handles Firebase Phone Auth APNs / URL callbacks for the SwiftUI app lifecycle.
//

import UIKit
import UserNotifications

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configure()

        #if canImport(FirebaseAuth) && DEBUG
        // Always on in DEBUG so Firebase console test numbers work without paid SMS.
        // Register +94 713123411 with code 123456 under Authentication → Phone → Phone numbers for testing.
        if FirebaseBootstrap.isConfigured {
            Auth.auth().settings?.isAppVerificationDisabledForTesting = true
        }
        #endif

        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        #endif
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if canImport(FirebaseAuth)
        if FirebaseBootstrap.isConfigured, Auth.auth().canHandleNotification(userInfo) {
            completionHandler(.noData)
            return
        }
        #endif
        completionHandler(.noData)
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return false }
        return Auth.auth().canHandle(url)
        #else
        return false
        #endif
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
