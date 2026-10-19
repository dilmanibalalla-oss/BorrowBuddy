import SwiftUI

enum AppTheme {
    static let blue = Color(red: 0.22, green: 0.47, blue: 0.62)
    static let yellow = Color(red: 1.00, green: 0.81, blue: 0.23)
    static let green = Color(red: 0.37, green: 0.51, blue: 0.43)
    static let coral = Color(red: 0.88, green: 0.45, blue: 0.36)
    static let background = Color(red: 0.99, green: 0.99, blue: 0.98)
    static let text = Color(red: 0.18, green: 0.18, blue: 0.19)
    static let secondaryText = Color(red: 0.43, green: 0.44, blue: 0.46)
    static let border = Color(red: 0.76, green: 0.81, blue: 0.85)
    static let shadow = Color.black.opacity(0.09)

    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
