import SwiftUI
import UIKit

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(AppTheme.rounded(16, weight: .bold))
            }
            .foregroundStyle(AppTheme.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppTheme.yellow.opacity(enabled ? 1 : 0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.blue, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: AppTheme.shadow, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}
