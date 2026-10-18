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
    let userProfileService: UserProfileService

    @Published var verificationID: String?
    @Published var verificationPhoneNumber = ""
    @Published var isAuthenticated = false

    /// Held after email signup so Face ID can store credentials for later unlock.
    var pendingCredentials: StoredCredentials?

    init(
        authenticationService: AuthenticationService = FirebaseAuthenticationService(),
        notificationService: NotificationService = LocalNotificationService(),
        userProfileService: UserProfileService = FirestoreUserProfileService()
    ) {
        self.authenticationService = authenticationService
        self.notificationService = notificationService
        self.userProfileService = userProfileService
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
