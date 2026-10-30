import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled = true
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        if enabled {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                action()
            } label: {
                face
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(.isButton)
            .accessibilityHintIfPresent(accessibilityHint)
        } else {
            face
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityRemoveTraits(.isButton)
        }
    }

    @ViewBuilder
    private var face: some View {
        if enabled {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(AppTheme.system(14, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(AppTheme.rounded(16, weight: .bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .foregroundStyle(AppTheme.onYellow)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(AppTheme.yellow)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.onYellow, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .shadow(color: AppTheme.shadow, radius: 0, x: 0, y: 5)
        } else {
            Text(title)
                .font(AppTheme.system(16, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
    }
}
