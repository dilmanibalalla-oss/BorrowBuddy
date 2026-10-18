//
//  PhoneSignInViewModel.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import Combine
import Foundation

final class PhoneSignInViewModel: ObservableObject {
    @Published var selectedCountry: Country = .defaultCountry
    @Published var phoneNumber = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    /// Only the exact hardcoded test digits unlock the next step.
    var matchesTestPhone: Bool {
        phoneNumber.filter(\.isNumber) == DevAuthFixtures.testPhoneDigits
    }

    var canContinue: Bool {
        matchesTestPhone && !isLoading
    }

    var fullPhoneNumber: String {
        "+\(selectedCountry.dialCode)\(phoneNumber.filter(\.isNumber))"
    }

    var displayPhoneNumber: String {
        "+\(selectedCountry.dialCode) \(phoneNumber)"
    }

    func selectCountry(_ country: Country) {
        selectedCountry = country
        format(phoneNumber)
    }

    func format(_ value: String) {
        var normalized = String(value.filter(\.isNumber))
        let dial = selectedCountry.dialCode
        if normalized.hasPrefix(dial), normalized.count > selectedCountry.maxNationalDigits {
            normalized.removeFirst(dial.count)
        }
        if normalized.hasPrefix("0") {
            normalized.removeFirst()
        }
        let digits = String(normalized.prefix(selectedCountry.maxNationalDigits))
        phoneNumber = Self.grouped(digits, for: selectedCountry)

        if digits.isEmpty {
            errorMessage = nil
        } else if digits == DevAuthFixtures.testPhoneDigits {
            errorMessage = nil
        } else if digits.count >= DevAuthFixtures.testPhoneDigits.count {
            errorMessage = "Incorrect phone number."
        } else {
            errorMessage = nil
        }
    }

    @MainActor
    func sendCode(using service: AuthenticationService) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard matchesTestPhone else {
            errorMessage = "Incorrect phone number."
            return nil
        }

        do {
            return try await service.sendVerificationCode(to: fullPhoneNumber)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private static func grouped(_ digits: String, for country: Country) -> String {
        guard country.id == "LK" else {
            var parts: [String] = []
            var index = digits.startIndex
            while index < digits.endIndex {
                let end = digits.index(index, offsetBy: 3, limitedBy: digits.endIndex) ?? digits.endIndex
                parts.append(String(digits[index..<end]))
                index = end
            }
            return parts.joined(separator: " ")
        }
        let first = digits.prefix(2)
        let middle = digits.dropFirst(2).prefix(3)
        let last = digits.dropFirst(5).prefix(4)
        return [String(first), String(middle), String(last)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
