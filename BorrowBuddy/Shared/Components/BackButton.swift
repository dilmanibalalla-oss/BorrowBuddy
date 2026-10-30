import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(AppTheme.system(15, weight: .medium))
                .accessibilityHidden(true)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
