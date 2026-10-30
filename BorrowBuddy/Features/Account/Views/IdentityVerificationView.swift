//
//  IdentityVerificationView.swift
//  BorrowBuddy
//

import PhotosUI
import SwiftUI
import UIKit

struct IdentityVerificationView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @State private var account = AccountSummary(
        displayName: "",
        neighborhood: "",
        phoneNumber: "",
        creditBalance: 0,
        creditHeld: 0
    )
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var documentImage: UIImage?
    @State private var addressConfirmed = false
    @State private var isSaving = false
    @State private var message: String?
    @State private var isError = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AccountSettingsHeader(title: "Identity Verification", subtitle: "Required for high-value tools") {
                        dismiss()
                    }
                    if account.identityVerified && account.addressConfirmed {
                        AccountNotice(
                            icon: "checkmark.seal",
                            title: "You're verified",
                            message: "You can request high-value tools. You can replace the ID photo below."
                        )
                    }
                    addressCard
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "person.text.rectangle")
                            Text(documentImage == nil ? "Upload a photo of your ID" : "Replace ID photo")
                        }
                        .font(AppTheme.rounded(15, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12).stroke(AppTheme.blue, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    if let documentImage {
                        Image(uiImage: documentImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Selected identity document")
                    }
                    Toggle(isOn: $addressConfirmed) {
                        Text("I confirm this is my local address")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                    }
                    .tint(AppTheme.blue)
                    .disabled(account.streetAddress.isEmpty)
                    if let message {
                        if isError {
                            DismissingErrorText(message: message, size: 12.5)
                        } else {
                            Text(message)
                                .font(.system(size: 12.5))
                                .foregroundStyle(AppTheme.green)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            PrimaryButton(title: isSaving ? "Saving..." : "Submit verification", enabled: !isSaving) {
                Task { await submit() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task { await load() }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOCAL ADDRESS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.green)
            Text(addressLine)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
            if account.streetAddress.isEmpty {
                Text("Save your shed address in location setup before confirming it.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var addressLine: String {
        let parts = [account.streetAddress, account.unit, account.postalCode, account.neighborhood]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "No address saved yet" : parts.joined(separator: ", ")
    }

    private func load() async {
        account = (try? await dependencies.accountRepository.loadAccount()) ?? account
        addressConfirmed = account.addressConfirmed && !account.streetAddress.isEmpty
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            return
        }
        documentImage = image
    }

    private func submit() async {
        guard !account.streetAddress.isEmpty else {
            isError = true
            message = "Add your local address before verifying."
            return
        }
        guard addressConfirmed else {
            isError = true
            message = "Confirm that this is your local address."
            return
        }
        guard let documentImage else {
            isError = true
            message = "Upload a photo of your ID."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let data = try PhotoEncoding.jpeg(documentImage)
            try await dependencies.accountRepository.saveIdentityVerification(documentData: data)
            isError = false
            message = "Identity and address saved. High-value tools are now available to request."
            await load()
        } catch {
            isError = true
            message = error.localizedDescription
        }
    }
}
