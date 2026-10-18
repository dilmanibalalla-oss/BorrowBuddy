//
//  FirebaseAuthenticationService.swift
//  BorrowBuddy
//

import FirebaseAuth
import Foundation

final class FirebaseAuthenticationService: AuthenticationService {
    private let verificationIDKey = "firebasePhoneAuthVerificationID"
    private let onboardingKeyPrefix = "onboardingCompleted."
    private var inMemoryVerificationID: String?

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
    }

    func signIn(email: String, password: String) async throws {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            throw AuthenticationError.emptyFields
        }
        _ = try await Auth.auth().signIn(withEmail: trimmedEmail, password: password)
    }

    func sendVerificationCode(to phoneNumber: String) async throws -> String {
        // Hardcoded test number: skip Firebase SMS (avoids paid SMS / app verification).
        if DevAuthFixtures.isTestPhone(phoneNumber) {
            verificationID = DevAuthFixtures.localVerificationID
            return DevAuthFixtures.localVerificationID
        }

        let receivedVerificationID = try await PhoneAuthProvider.provider().verifyPhoneNumber(
            phoneNumber,
            uiDelegate: nil
        )
        verificationID = receivedVerificationID
        return receivedVerificationID
    }

    func verify(code: String, verificationID suppliedVerificationID: String?) async throws {
        guard let savedVerificationID = suppliedVerificationID ?? verificationID else {
            throw AuthenticationError.verificationNotStarted
        }

        // Local test OTP path — no Firebase phone credential required.
        if DevAuthFixtures.isLocalVerificationID(savedVerificationID) {
            guard code == DevAuthFixtures.testVerificationCode else {
                throw AuthenticationError.invalidCode
            }
            guard Auth.auth().currentUser != nil else {
                throw CommunityError.signInRequired
            }
            verificationID = nil
            return
        }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: savedVerificationID,
            verificationCode: code
        )

        if let currentUser = Auth.auth().currentUser {
            // New sign-up path: link phone to the existing email account.
            do {
                _ = try await currentUser.link(with: credential)
            } catch let error as NSError
                where AuthErrorCode(rawValue: error.code) == .credentialAlreadyInUse
                || AuthErrorCode(rawValue: error.code) == .providerAlreadyLinked {
                // Phone already associated — continue onboarding.
            }
        } else {
            _ = try await Auth.auth().signIn(with: credential)
        }

        verificationID = nil
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
