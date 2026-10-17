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

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)

            field
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.text)
                .padding(.horizontal, 15)
                .frame(height: 54)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AppTheme.border, lineWidth: 1.5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    @ViewBuilder
    private var field: some View {
        switch kind {
        case .password, .newPassword:
            SecureField(placeholder, text: $text)
                .textContentType(kind == .newPassword ? .newPassword : .password)
        case .email:
            TextField(placeholder, text: $text)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #if os(iOS)
                .keyboardType(.emailAddress)
                #endif
        case .name:
            TextField(placeholder, text: $text)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
        case .street:
            TextField(placeholder, text: $text)
                .textContentType(.streetAddressLine1)
        case .unit:
            TextField(placeholder, text: $text)
                .textContentType(.streetAddressLine2)
        case .city:
            TextField(placeholder, text: $text)
                .textContentType(.addressCity)
        case .postal:
            TextField(placeholder, text: $text)
                .textContentType(.postalCode)
        case .plain:
            TextField(placeholder, text: $text)
        }
    }
}
