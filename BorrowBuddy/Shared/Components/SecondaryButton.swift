//
//  SecondaryButton.swift
//  BorrowBuddy
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.rounded(16, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.blue, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
}
