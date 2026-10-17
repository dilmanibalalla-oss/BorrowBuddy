//
//  AppDependencies.swift
//  BorrowBuddy
//

import Combine
import Foundation

@MainActor
final class AppDependencies: ObservableObject {
    let authenticationService: AuthenticationService
    let notificationService: NotificationService

    @Published var verificationID: String?
    @Published var verificationPhoneNumber = ""
    @Published var isAuthenticated = false

    init(
        authenticationService: AuthenticationService = FirebaseAuthenticationService(),
        notificationService: NotificationService = LocalNotificationService()
    ) {
        self.authenticationService = authenticationService
        self.notificationService = notificationService
    }

    func observeAuthentication() {
        Task {
            for await isSignedIn in authenticationService.authenticationStateChanges() {
                isAuthenticated = isSignedIn
            }
        }
    }
}

protocol NotificationService {
    func registerToken() async
}

final class LocalNotificationService: NotificationService {
    func registerToken() async {
        // Push token registration can be wired to Firebase Messaging later.
    }
}
