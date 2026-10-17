//
//  VerificationViewModel.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import Combine
import Foundation

final class VerificationViewModel: ObservableObject {
    @Published var code = ""
    @Published private(set) var secondsRemaining = 59
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?
    private var timer: AnyCancellable?

    var canVerify: Bool {
        code.count == 6
    }

    init() {
        startTimer()
    }

    func updateCode(_ value: String) {
        code = String(value.filter(\.isNumber).prefix(6))
    }

    @MainActor
    func resend(to phoneNumber: String, using service: AuthenticationService) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let verificationID = try await service.sendVerificationCode(
                to: phoneNumber.replacingOccurrences(of: " ", with: "")
            )
            secondsRemaining = 59
            code = ""
            statusMessage = "A new code was requested. Enter the new code, not the previous one."
            startTimer()
            return verificationID
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    @MainActor
    func verify(
        phoneNumber: String,
        verificationID: String?,
        using service: AuthenticationService
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard canVerify else { throw AuthenticationError.invalidCode }
            try await service.verify(code: code, verificationID: verificationID)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func startTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, secondsRemaining > 0 else { return }
                secondsRemaining -= 1
            }
    }
}
