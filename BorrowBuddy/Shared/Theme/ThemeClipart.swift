import SwiftUI

struct ThemeClipart: View {
    var name: String
    var height: CGFloat = 168
    var label: String

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityLabel(label)
    }
}
