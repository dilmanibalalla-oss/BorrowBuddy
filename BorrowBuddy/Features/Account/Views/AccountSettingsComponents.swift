//
//  AccountSettingsComponents.swift
//  BorrowBuddy
//

import SwiftUI

struct AccountSettingsHeader: View {
    let title: String
    let subtitle: String
    let backAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            BackButton(action: backAction)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
        }
    }
}

struct AccountField: View {
    let title: String
    var icon: String? = nil
    var isEditable: Bool = true
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.blue)
            HStack(spacing: 10) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 20)
                }
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(isEditable ? .words : .never)
                    .autocorrectionDisabled(!isEditable)
                    .disabled(!isEditable)
                    .font(.system(size: 14))
                    .foregroundStyle(isEditable ? AppTheme.text : AppTheme.secondaryText)
            }
            .padding(.horizontal, 13)
            .frame(height: 48)
            .background(isEditable ? AppTheme.surface : AppTheme.blue.opacity(0.16))
            .overlay {
                RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }
}

struct AccountSaveStatus: View {
    let error: String?
    let success: String?

    var body: some View {
        if let error {
            Label(error, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.coral)
        } else if let success {
            Label(success, systemImage: "checkmark.circle.fill")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(AppTheme.green)
        }
    }
}

struct AccountNotice: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.blue.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AccountCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
