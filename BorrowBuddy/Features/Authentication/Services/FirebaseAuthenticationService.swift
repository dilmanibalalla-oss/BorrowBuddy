//
//  FirebaseAuthenticationService.swift
//  BorrowBuddy
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import UIKit

final class FirebaseAuthenticationService: AuthenticationService {
    private let verificationIDKey = "firebasePhoneAuthVerificationID"
    private let pendingPhoneKey = "firebasePhoneAuthPendingNumber"
    private let verifiedPhoneKeyPrefix = "verifiedPhone."
    private let onboardingKeyPrefix = "onboardingCompleted."
    private var inMemoryVerificationID: String?
    private var authPresenter: FirebaseAuthPresenter?

    private var verificationID: String? {
        get {
            inMemoryVerificationID
                ?? UserDefaults.standard.string(forKey: verificationIDKey)
        }
        set {
            inMemoryVerificationID = newValue
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: verificationIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: verificationIDKey)
            }
        }
    }

    var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    var currentDisplayName: String? {
        Auth.auth().currentUser?.displayName
    }

    func authenticationStateChanges() -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let handle = Auth.auth().addStateDidChangeListener { _, user in
                continuation.yield(user != nil)
            }
            continuation.onTermination = { _ in
                Auth.auth().removeStateDidChangeListener(handle)
            }
        }
    }

    func signUp(fullName: String, email: String, password: String) async throws {
        let trimmedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedName.isEmpty, !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyFields
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            throw AuthenticationError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthenticationError.weakPassword
        }

        let result = try await Auth.auth().createUser(withEmail: trimmedEmail, password: password)
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = trimmedName
        try await changeRequest.commitChanges()
        setOnboardingCompleted(false, for: result.user.uid)
        try? await Firestore.firestore().collection("users").document(result.user.uid).setData(
            [
                "displayName": trimmedName,
                "email": trimmedEmail,
                "creditBalance": AccountSummary.newAccountCredits,
                "creditHeld": 0,
                "starterCreditsGranted": true,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyFields
        }
        _ = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
    }

    func signInWithGoogle() async throws {
        let provider = OAuthProvider(providerID: "google.com")
        provider.customParameters = ["prompt": "select_account"]
        provider.scopes = ["email", "profile"]
        let presenter = makePresenter()
        do {
            _ = try await Auth.auth().signIn(with: provider, uiDelegate: presenter)
            authPresenter = nil
        } catch {
            authPresenter = nil
            throw Self.mappedAuthError(error)
        }
    }

    func sendVerificationCode(to phoneNumber: String) async throws -> String {
        let digits = phoneNumber.filter(\.isNumber)
        guard digits.count >= 8 else {
            throw CommunityError.invalidInput("Enter a valid phone number with the correct country code.")
        }

        // Firebase SMS (Phone Auth) requires the paid Blaze plan. The free Spark
        // plan keeps email/password, so this step accepts the local code instead.
        UserDefaults.standard.set(phoneNumber, forKey: pendingPhoneKey)
        verificationID = DevAuthFixtures.localVerificationID
        return DevAuthFixtures.localVerificationID
    }

    func verify(code: String, verificationID suppliedVerificationID: String?) async throws {
        guard let savedVerificationID = suppliedVerificationID ?? verificationID else {
            throw AuthenticationError.verificationNotStarted
        }

        guard DevAuthFixtures.isLocalVerificationID(savedVerificationID) else {
            verificationID = nil
            throw AuthenticationError.verificationNotStarted
        }
        guard code == DevAuthFixtures.testVerificationCode else {
            throw AuthenticationError.invalidCode
        }

        if Auth.auth().currentUser == nil {
            do {
                _ = try await Auth.auth().signInAnonymously()
            } catch {
                throw CommunityError.invalidInput("Create an account with email and password first.")
            }
        }

        let phoneNumber = UserDefaults.standard.string(forKey: pendingPhoneKey)
        if let uid = Auth.auth().currentUser?.uid, let phoneNumber, !phoneNumber.isEmpty {
            UserDefaults.standard.set(phoneNumber, forKey: verifiedPhoneKeyPrefix + uid)
            try? await Firestore.firestore().collection("users").document(uid).setData(
                [
                    "phoneNumber": phoneNumber,
                    "updatedAt": FieldValue.serverTimestamp()
                ],
                merge: true
            )
        }

        UserDefaults.standard.removeObject(forKey: pendingPhoneKey)
        verificationID = nil
    }

    private func makePresenter() -> FirebaseAuthPresenter {
        let presenter = FirebaseAuthPresenter()
        authPresenter = presenter
        return presenter
    }

    private static func mappedAuthError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }
        switch code {
        case .invalidPhoneNumber:
            return CommunityError.invalidInput("Enter a valid phone number with the correct country code.")
        case .invalidVerificationCode:
            return AuthenticationError.invalidCode
        case .sessionExpired:
            return CommunityError.invalidInput("That code expired. Request a new one.")
        case .tooManyRequests, .quotaExceeded:
            return CommunityError.invalidInput("Too many texts were sent. Wait a few minutes and try again.")
        case .missingClientIdentifier, .invalidAppCredential, .appNotAuthorized, .captchaCheckFailed:
            return CommunityError.invalidInput("Phone verification isn't available right now. Try again in a moment.")
        case .webContextCancelled, .webContextAlreadyPresented:
            return CommunityError.invalidInput("Sign-in was cancelled. Try again.")
        default:
            return error
        }
    }

    func prepareAccount() async throws {
        guard Auth.auth().currentUser != nil else { throw CommunityError.signInRequired }
    }

    func completeOnboarding() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw CommunityError.signInRequired }
        setOnboardingCompleted(true, for: uid)
    }

    func hasCompletedOnboarding() async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        return UserDefaults.standard.bool(forKey: onboardingKeyPrefix + uid)
    }

    func signOut() throws {
        try Auth.auth().signOut()
        verificationID = nil
    }

    private func setOnboardingCompleted(_ completed: Bool, for uid: String) {
        UserDefaults.standard.set(completed, forKey: onboardingKeyPrefix + uid)
    }
}

private final class FirebaseAuthPresenter: NSObject, AuthUIDelegate {
    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        guard let presenter = Self.topViewController() else {
            completion?()
            return
        }
        presenter.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        Self.topViewController()?.dismiss(animated: flag, completion: completion)
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        if let navigation = root as? UINavigationController {
            return topViewController(base: navigation.visibleViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
