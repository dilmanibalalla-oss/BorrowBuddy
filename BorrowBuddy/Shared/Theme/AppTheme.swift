//
//  AppTheme.swift
//  BorrowBuddy
//

import SwiftUI

enum AppTheme {
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.0)
    static let blue = Color(red: 0.12, green: 0.20, blue: 0.35)
    static let text = Color(red: 0.18, green: 0.22, blue: 0.28)
    static let secondaryText = Color(red: 0.45, green: 0.49, blue: 0.55)
    static let border = Color(red: 0.86, green: 0.88, blue: 0.91)
    static let coral = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let green = Color(red: 0.18, green: 0.64, blue: 0.40)
    static let background = Color.white
    static let cardBackground = Color(red: 0.97, green: 0.97, blue: 0.98)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
