//
//  AuthTextField.swift
//  BorrowBuddy
//

import SwiftUI

enum AuthFieldKind {
    case name
    case email
    case password
    case newPassword
    case street
    case unit
    case city
    case postal
    case plain
}

struct AuthTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var kind: AuthFieldKind = .plain
    var autofocus = false

    @State private var focusTrigger = 0
    @State private var isFocused = false

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)

            RespondableTextField(
                text: $text,
                placeholder: placeholder,
                keyboardType: keyboardType,
                textContentType: contentType,
                isSecure: isSecure,
                autocapitalization: autocapitalization,
                autocorrection: autocorrection,
                focusTrigger: focusTrigger
            )
            .frame(height: 22)
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(isFocused ? AppTheme.blue : AppTheme.border, lineWidth: isFocused ? 2 : 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
            .onTapGesture {
                focusTrigger += 1
                isFocused = true
            }
        }
        .onAppear {
            guard autofocus else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusTrigger += 1
                isFocused = true
            }
        }
    }

    private var isSecure: Bool {
        kind == .password || kind == .newPassword
    }

    private var keyboardType: UIKeyboardType {
        switch kind {
        case .email: return .emailAddress
        case .postal: return .numbersAndPunctuation
        default: return .default
        }
    }

    private var contentType: UITextContentType? {
        switch kind {
        case .email: return .emailAddress
        case .password: return .password
        case .newPassword: return .newPassword
        case .name: return .name
        case .street: return .streetAddressLine1
        case .unit: return .streetAddressLine2
        case .city: return .addressCity
        case .postal: return .postalCode
        case .plain: return nil
        }
    }

    private var autocapitalization: UITextAutocapitalizationType {
        switch kind {
        case .email, .password, .newPassword: return .none
        case .name, .street, .city: return .words
        default: return .sentences
        }
    }

    private var autocorrection: UITextAutocorrectionType {
        switch kind {
        case .email, .password, .newPassword: return .no
        default: return .default
        }
    }
}
