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
        code.count == 6 && !isLoading
    }

    init() {
        startTimer()
    }

    func updateCode(_ value: String) {
        let next = String(value.filter(\.isNumber).prefix(6))
        if next != code {
            errorMessage = nil
        }
        code = next
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
        guard code.count == 6 else {
            errorMessage = "Enter the 6-digit verification code."
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await service.verify(code: code, verificationID: verificationID)
            return true
        } catch let error as AuthenticationError {
            switch error {
            case .invalidCode:
                errorMessage = "Incorrect verification code."
            default:
                errorMessage = error.localizedDescription
            }
            return false
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
