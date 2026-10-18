//
//  Country.swift
//  BorrowBuddy
//

import Foundation

struct Country: Identifiable, Hashable {
    let id: String // ISO 3166-1 alpha-2
    let name: String
    let dialCode: String
    let maxNationalDigits: Int

    /// Flag glyph built from the ISO region code (not a hardcoded emoji literal).
    var flag: String {
        id.uppercased().unicodeScalars.compactMap { scalar in
            guard let regional = UnicodeScalar(127397 + scalar.value) else { return nil }
            return String(regional)
        }.joined()
    }

    var displayDialCode: String { "+\(dialCode)" }

    static let all: [Country] = [
        Country(id: "LK", name: "Sri Lanka", dialCode: "94", maxNationalDigits: 9),
        Country(id: "US", name: "United States", dialCode: "1", maxNationalDigits: 10),
        Country(id: "CA", name: "Canada", dialCode: "1", maxNationalDigits: 10),
        Country(id: "GB", name: "United Kingdom", dialCode: "44", maxNationalDigits: 10),
        Country(id: "AU", name: "Australia", dialCode: "61", maxNationalDigits: 9),
        Country(id: "IN", name: "India", dialCode: "91", maxNationalDigits: 10),
        Country(id: "AE", name: "United Arab Emirates", dialCode: "971", maxNationalDigits: 9),
        Country(id: "SG", name: "Singapore", dialCode: "65", maxNationalDigits: 8),
        Country(id: "MY", name: "Malaysia", dialCode: "60", maxNationalDigits: 10),
        Country(id: "DE", name: "Germany", dialCode: "49", maxNationalDigits: 11),
        Country(id: "FR", name: "France", dialCode: "33", maxNationalDigits: 9),
        Country(id: "JP", name: "Japan", dialCode: "81", maxNationalDigits: 10),
        Country(id: "NZ", name: "New Zealand", dialCode: "64", maxNationalDigits: 9),
        Country(id: "PH", name: "Philippines", dialCode: "63", maxNationalDigits: 10),
        Country(id: "PK", name: "Pakistan", dialCode: "92", maxNationalDigits: 10),
        Country(id: "BD", name: "Bangladesh", dialCode: "880", maxNationalDigits: 10),
        Country(id: "NP", name: "Nepal", dialCode: "977", maxNationalDigits: 10),
        Country(id: "SA", name: "Saudi Arabia", dialCode: "966", maxNationalDigits: 9),
        Country(id: "QA", name: "Qatar", dialCode: "974", maxNationalDigits: 8),
        Country(id: "KW", name: "Kuwait", dialCode: "965", maxNationalDigits: 8)
    ].sorted { $0.name < $1.name }

    static let defaultCountry: Country = all.first { $0.id == "LK" } ?? all[0]
}
