//
//  DevAuthFixtures.swift
//  BorrowBuddy
//
//  Local phone check — skips Firebase SMS so the free Spark plan can be used.
//

import Foundation

enum DevAuthFixtures {
    /// National number digits only (without country dial code).
    static let testPhoneDigits = "713123411"
    /// Fixed OTP accepted locally for the test phone.
    static let testVerificationCode = "123456"
    /// Sentinel verification ID used when SMS is bypassed.
    static let localVerificationID = "borrowbuddy-local-test-verification"

    static func isTestPhone(_ phoneNumber: String) -> Bool {
        let digits = phoneNumber.filter(\.isNumber)
        return digits.hasSuffix(testPhoneDigits) || digits == testPhoneDigits
    }

    static func isLocalVerificationID(_ verificationID: String?) -> Bool {
        verificationID == localVerificationID
    }
}
