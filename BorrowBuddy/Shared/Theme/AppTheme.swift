//
//  AppTheme.swift
//  BorrowBuddy
//

import SwiftUI

enum AppTheme {
    static let yellow = Color(red: 1.0, green: 0.82, blue: 0.28) // #FFD147
    static let blue = Color(red: 0.17, green: 0.37, blue: 0.52) // #2C5E85
    static let text = Color(red: 0.17, green: 0.37, blue: 0.52)
    static let secondaryText = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let border = Color(red: 0.78, green: 0.84, blue: 0.90)
    static let coral = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let green = Color(red: 0.18, green: 0.64, blue: 0.40)
    static let background = Color(red: 0.98, green: 0.97, blue: 0.96) // #F9F8F5
    static let cardBackground = Color(red: 0.97, green: 0.97, blue: 0.98)
    /// Hard offset shadow used by primary CTAs and the logo.
    static let shadow = Color(red: 0.17, green: 0.37, blue: 0.52).opacity(0.22)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
