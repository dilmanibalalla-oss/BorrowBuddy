//
//  EditProfileView.swift
//  BorrowBuddy
//

import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct EditProfileView: View {
    var onSaved: (AccountSummary) -> Void
    var onCancel: () -> Void

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = AccountSettingsViewModel()
    @State private var displayName: String
    @State private var neighborhood: String
    @State private var phoneNumber: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoError: String?
    @State private var changedPhoto = false
    @State private var photoTask: Task<Void, Never>?
    @State private var isSaving = false
    @State private var stickyError: String?

    init(startingAccount: AccountSummary?, onSaved: @escaping (AccountSummary) -> Void, onCancel: @escaping () -> Void) {
        self.onSaved = onSaved
        self.onCancel = onCancel
        let seededNeighborhood = (startingAccount?.neighborhood.isEmpty == false)
            ? startingAccount?.neighborhood ?? ""
            : startingAccount?.streetAddress ?? ""
        _displayName = State(initialValue: startingAccount?.displayName ?? "")
        _neighborhood = State(initialValue: seededNeighborhood)
        _phoneNumber = State(initialValue: startingAccount?.phoneNumber ?? "")
        _photoData = State(initialValue: startingAccount?.photoData)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    AccountSettingsHeader(title: "Edit Profile", subtitle: "Your neighborhood identity") {
                        onCancel()
                    }
                    avatar
                    AccountField(
                        title: "Full name",
                        icon: "person",
                        textContentType: .name,
                        text: $displayName
                    )
                    AccountField(
                        title: "Neighborhood",
                        icon: "mappin.circle",
                        textContentType: .addressCity,
                        text: $neighborhood
                    )
                    AccountField(
                        title: "Phone number",
                        icon: "phone",
                        isEditable: false,
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber,
                        text: $phoneNumber
                    )
                    Button("Edit saved address") {
                        router.go(to: .savedLocation)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.blue)
                    AccountNotice(
                        icon: "shield.checkered",
                        title: "Your account",
                        message: "Your phone number was confirmed when you joined and stays on your account. Your name and neighborhood are saved when you tap Save profile."
                    )
                    if let message = stickyError ?? photoError {
                        Text(message)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.coral)
                            .accessibilityLabel(message)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            PrimaryButton(
                title: isSaving ? "Saving..." : "Save profile",
                enabled: !isSaving
            ) {
                Task { await save() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .onChange(of: selectedPhoto) { _, selection in
            photoTask?.cancel()
            photoTask = Task { @MainActor in
                guard let selection else { return }
                do {
                    guard let picked = try await selection.loadTransferable(type: ProfilePhoto.self) else { return }
                    guard !Task.isCancelled, let image = UIImage(data: picked.data) else { return }
                    photoData = try PhotoEncoding.jpeg(image)
                    changedPhoto = true
                    photoError = nil
                } catch {
                    guard !Task.isCancelled else { return }
                    photoError = FriendlyError.clean(error.localizedDescription)
                }
            }
        }
    }

    private var avatar: some View {
        VStack(spacing: 9) {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Circle()
                    .fill(AppTheme.yellow.opacity(0.45))
                    .frame(width: 92, height: 92)
                    .overlay {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 92, height: 92)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 39))
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                    .clipShape(Circle())
            }
            Text("Change profile photo")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.blue)
            Text("Profile details")
                .font(AppTheme.rounded(15, weight: .bold))
                .foregroundStyle(AppTheme.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        photoError = nil
        stickyError = nil
        defer { isSaving = false }

        await photoTask?.value

        let savedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let savedNeighborhood = neighborhood.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = await viewModel.saveProfile(
            displayName: savedName,
            neighborhood: savedNeighborhood,
            phoneNumber: phoneNumber,
            using: dependencies.accountRepository
        )
        guard saved else {
            stickyError = viewModel.errorMessage ?? "Your profile could not be saved."
            return
        }

        if changedPhoto, let photoData {
            do {
                try await dependencies.accountRepository.updateProfilePhoto(photoData)
            } catch {
                photoError = FriendlyError.clean(error.localizedDescription)
                onSaved(publishSavedProfile(name: savedName, neighborhood: savedNeighborhood))
                return
            }
        }

        let savedAccount = publishSavedProfile(name: savedName, neighborhood: savedNeighborhood)
        onSaved(savedAccount)
    }

    @discardableResult
    private func publishSavedProfile(name: String, neighborhood: String) -> AccountSummary {
        let latest = viewModel.account
        let savedAccount = AccountSummary(
            displayName: name,
            neighborhood: neighborhood,
            phoneNumber: latest?.phoneNumber.isEmpty == false ? latest!.phoneNumber : phoneNumber,
            creditBalance: latest?.creditBalance ?? 0,
            creditHeld: latest?.creditHeld ?? 0,
            photoData: photoData ?? latest?.photoData,
            latitude: latest?.latitude,
            longitude: latest?.longitude,
            streetAddress: latest?.streetAddress ?? "",
            unit: latest?.unit ?? "",
            postalCode: latest?.postalCode ?? "",
            identityVerified: latest?.identityVerified ?? false,
            addressConfirmed: latest?.addressConfirmed ?? false,
            isPro: latest?.isPro ?? false
        )
        dependencies.offlineCache.saveAccount(savedAccount)
        dependencies.editedAccount = savedAccount
        return savedAccount
    }
}

private struct ProfilePhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ProfilePhoto(data: data)
        }
    }
}
