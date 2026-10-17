//
//  PrimaryButton.swift
//  BorrowBuddy
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.rounded(17, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(enabled ? AppTheme.yellow : AppTheme.yellow.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!enabled)
        .buttonStyle(.plain)
    }
}
