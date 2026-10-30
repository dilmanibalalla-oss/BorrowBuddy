import SwiftUI
import UIKit

enum AppTheme {
    static let darkModeKey = "borrowBuddyDarkMode"

    static let blue = adaptive(
        light: UIColor(red: 0.22, green: 0.47, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.64, green: 0.86, blue: 0.97, alpha: 1)
    )
    static let onYellow = adaptive(
        light: UIColor(red: 0.22, green: 0.47, blue: 0.62, alpha: 1),
        dark: UIColor(red: 0.14, green: 0.32, blue: 0.46, alpha: 1)
    )
    static let onBlue = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.11, blue: 0.14, alpha: 1)
    )
    static let yellow = Color(red: 1.00, green: 0.81, blue: 0.23)
    static let green = adaptive(
        light: UIColor(red: 0.37, green: 0.51, blue: 0.43, alpha: 1),
        dark: UIColor(red: 0.66, green: 0.84, blue: 0.70, alpha: 1)
    )
    static let coral = adaptive(
        light: UIColor(red: 0.88, green: 0.45, blue: 0.36, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.66, blue: 0.56, alpha: 1)
    )
    static let background = adaptive(
        light: UIColor(red: 0.99, green: 0.99, blue: 0.98, alpha: 1),
        dark: UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
    )
    static let surface = adaptive(
        light: UIColor(white: 1, alpha: 1),
        dark: UIColor(red: 0.15, green: 0.18, blue: 0.21, alpha: 1)
    )
    static let text = adaptive(
        light: UIColor(red: 0.18, green: 0.18, blue: 0.19, alpha: 1),
        dark: UIColor(red: 0.96, green: 0.97, blue: 0.96, alpha: 1)
    )
    static let secondaryText = adaptive(
        light: UIColor(red: 0.43, green: 0.44, blue: 0.46, alpha: 1),
        dark: UIColor(red: 0.78, green: 0.82, blue: 0.85, alpha: 1)
    )
    static let border = adaptive(
        light: UIColor(red: 0.76, green: 0.81, blue: 0.85, alpha: 1),
        dark: UIColor(red: 0.36, green: 0.43, blue: 0.49, alpha: 1)
    )
    static let shadow = Color.black.opacity(0.09)

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    /// Keeps the designed size at the default content size, then follows Dynamic Type.
    static func system(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        let scaled = UIFontMetrics(forTextStyle: textStyle(for: size)).scaledFont(for: base)
        return Font(scaled)
    }

    /// Keeps the designed size at the default content size, then follows Dynamic Type.
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        let roundedFont = UIFont(descriptor: descriptor, size: size)
        let scaled = UIFontMetrics(forTextStyle: textStyle(for: size)).scaledFont(for: roundedFont)
        return Font(scaled)
    }

    private static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<12: .caption2
        case ..<14: .caption1
        case ..<16: .footnote
        case ..<18: .subheadline
        case ..<22: .body
        case ..<26: .title3
        case ..<32: .title2
        default: .title1
        }
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        if weight == .heavy || weight == .black { return .heavy }
        if weight == .bold { return .bold }
        if weight == .semibold { return .semibold }
        if weight == .medium { return .medium }
        if weight == .light || weight == .thin || weight == .ultraLight { return .light }
        return .regular
    }
}

extension View {
    /// Speaks new messages when VoiceOver is running. Empty values are ignored.
    func accessibilityAnnounce(_ message: String?) -> some View {
        onChange(of: message) { _, newValue in
            guard UIAccessibility.isVoiceOverRunning, let newValue, !newValue.isEmpty else { return }
            UIAccessibility.post(notification: .announcement, argument: newValue)
        }
    }

    @ViewBuilder
    func accessibilityHintIfPresent(_ hint: String?) -> some View {
        if let hint, !hint.isEmpty {
            self.accessibilityHint(hint)
        } else {
            self
        }
    }
}
