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

    var matchesTestCode: Bool {
        code == DevAuthFixtures.testVerificationCode
    }

    var canVerify: Bool {
        matchesTestCode && !isLoading
    }

    init() {
        startTimer()
    }

    func updateCode(_ value: String) {
        code = String(value.filter(\.isNumber).prefix(6))
        if code.isEmpty {
            errorMessage = nil
        } else if code.count == 6, code != DevAuthFixtures.testVerificationCode {
            errorMessage = "Incorrect verification code."
        } else {
            errorMessage = nil
        }
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
            statusMessage = "Enter the verification code again."
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
            guard matchesTestCode else {
                errorMessage = "Incorrect verification code."
                return false
            }
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
