//
//  AppDelegate.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import SwiftUI
import UIKit
import UserNotifications
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    private var router: AppRouter?
    private var dependencies: AppDependencies?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configure()

        #if canImport(FirebaseAuth) && DEBUG
        // Opt-in only: this flag rejects real numbers and accepts Firebase console test numbers.
        if FirebaseBootstrap.isConfigured {
            Auth.auth().settings?.isAppVerificationDisabledForTesting = ProcessInfo.processInfo.arguments.contains("--firebase-test-phone")
        }
        #endif

        router = AppRouter()
        dependencies = AppDependencies()
        UNUserNotificationCenter.current().delegate = self
        #if canImport(FirebaseMessaging)
        if FirebaseBootstrap.isConfigured { Messaging.messaging().delegate = self }
        #endif

        application.registerForRemoteNotifications()
        return true
    }

    func makeRootViewController() -> UIViewController {
        guard let router, let dependencies else {
            preconditionFailure("App dependencies must be initialized before connecting a scene.")
        }
        let rootView = RootView()
            .environmentObject(router)
            .environmentObject(dependencies)
            .environmentObject(dependencies.borrowingFlow)
            .environmentObject(dependencies.loanLifecycle)
            .preferredColorScheme(.light)
        return UIHostingController(rootView: rootView)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        Auth.auth().setAPNSToken(deviceToken, type: .unknown)
        #endif
        #if canImport(FirebaseMessaging)
        if FirebaseBootstrap.isConfigured { Messaging.messaging().apnsToken = deviceToken }
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
        handleIncomingURL(url)
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        #if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return false }
        return Auth.auth().canHandle(url)
        #else
        return false
        #endif
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if dependencies?.authenticationService.currentUserID != nil { router?.go(to: .loanList) }
        completionHandler()
    }
}
#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { await dependencies?.notificationService.registerToken(fcmToken) }
    }
}
#endif
