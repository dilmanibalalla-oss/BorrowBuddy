import SwiftUI
import UIKit

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
