//
//  PhoneSignInViewModel.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import Combine
import Foundation

final class PhoneSignInViewModel: ObservableObject {
    @Published var phoneNumber = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    var canContinue: Bool {
        phoneNumber.filter(\.isNumber).count >= 9
    }

    var fullPhoneNumber: String {
        "+94\(phoneNumber.filter(\.isNumber))"
    }

    var displayPhoneNumber: String {
        "+94 \(phoneNumber)"
    }

    func format(_ value: String) {
        var normalized = String(value.filter(\.isNumber))
        if normalized.hasPrefix("94"), normalized.count > 9 {
            normalized.removeFirst(2)
        }
        if normalized.hasPrefix("0") {
            normalized.removeFirst()
        }
        let digits = normalized.prefix(9)
        let first = digits.prefix(2)
        let middle = digits.dropFirst(2).prefix(3)
        let last = digits.dropFirst(5).prefix(4)
        phoneNumber = [String(first), String(middle), String(last)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    @MainActor
    func sendCode(using service: AuthenticationService) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await service.sendVerificationCode(to: fullPhoneNumber)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}
