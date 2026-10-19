import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 48, height: 48)
                .background(AppTheme.background)
                .overlay {
                    Circle().stroke(AppTheme.blue, lineWidth: 6)
                }
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
