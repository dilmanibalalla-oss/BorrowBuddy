//
//  RespondableTextField.swift
//  BorrowBuddy
//
//  UIKit-backed field so the software keyboard reliably appears (SwiftUI FocusState is flaky).
//

import SwiftUI
import UIKit

struct RespondableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var isSecure = false
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var autocorrection: UITextAutocorrectionType = .default
    var textAlignment: NSTextAlignment = .left
    var font: UIFont = .systemFont(ofSize: 17)
    var textColor: UIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.93, green: 0.96, blue: 0.98, alpha: 1)
            : UIColor(red: 0.17, green: 0.37, blue: 0.52, alpha: 1)
    }
    var tintColor: UIColor = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.64, green: 0.86, blue: 0.97, alpha: 1)
            : UIColor(red: 0.17, green: 0.37, blue: 0.52, alpha: 1)
    }
    var isInvisible = false
    var maxLength: Int? = nil
    var filterDigitsOnly = false
    var focusTrigger: Int = 0
    var accessibilityLabelText: String? = nil
    var scalesWithDynamicType = true
    var onCommit: (() -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.isSecureTextEntry = isSecure
        field.autocapitalizationType = autocapitalization
        field.autocorrectionType = autocorrection
        field.textAlignment = textAlignment
        field.font = scaledFont
        field.adjustsFontForContentSizeCategory = false
        field.textColor = isInvisible ? .clear : textColor
        field.tintColor = isInvisible ? .clear : tintColor
        field.backgroundColor = .clear
        field.borderStyle = .none
        field.returnKeyType = .done
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.setContentHuggingPriority(.required, for: .vertical)
        if let textContentType {
            field.textContentType = textContentType
        }
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.isSecureTextEntry = isSecure
        uiView.autocapitalizationType = autocapitalization
        uiView.autocorrectionType = autocorrection
        uiView.font = scaledFont
        uiView.adjustsFontForContentSizeCategory = false
        uiView.textColor = isInvisible ? .clear : textColor
        uiView.tintColor = isInvisible ? .clear : tintColor
        if let accessibilityLabelText {
            uiView.accessibilityLabel = accessibilityLabelText
        }

        if focusTrigger != context.coordinator.lastFocusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    private var scaledFont: UIFont {
        _ = dynamicTypeSize
        guard scalesWithDynamicType else { return font }
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: font)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: RespondableTextField
        var lastFocusTrigger: Int = -1

        init(_ parent: RespondableTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            var value = field.text ?? ""
            if parent.filterDigitsOnly {
                value = value.filter(\.isNumber)
            }
            if let maxLength = parent.maxLength {
                value = String(value.prefix(maxLength))
            }
            if field.text != value {
                field.text = value
            }
            parent.text = value
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit?()
            return true
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            // Ensure software keyboard is requested even if hardware keyboard is connected.
            textField.reloadInputViews()
        }
    }
}
