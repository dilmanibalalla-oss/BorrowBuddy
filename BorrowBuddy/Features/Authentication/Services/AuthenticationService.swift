//
//  AuthenticationService.swift
//  BorrowBuddy
//

import Foundation

protocol AuthenticationService: AnyObject {
    var currentUserID: String? { get }
    var currentDisplayName: String? { get }

    func authenticationStateChanges() -> AsyncStream<Bool>
    func signUp(fullName: String, email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func sendVerificationCode(to phoneNumber: String) async throws -> String
    func verify(code: String, verificationID: String?) async throws
    func prepareAccount() async throws
    func completeOnboarding() async throws
    func hasCompletedOnboarding() async throws -> Bool
    func signOut() throws
}
