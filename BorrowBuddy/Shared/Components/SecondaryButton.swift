//
//  SecondaryButton.swift
//  BorrowBuddy
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    var enabled = true
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        if enabled {
            Button(action: action) {
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
            Text(title)
                .font(AppTheme.rounded(16, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(AppTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Text(title)
                .font(AppTheme.system(16, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: .infinity, minHeight: 54)
        }
    }
}
