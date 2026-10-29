//
//  EditProfileView.swift
//  BorrowBuddy
//

import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountSettingsViewModel()
    @State private var displayName = ""
    @State private var neighborhood = ""
    @State private var phoneNumber = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoError: String?
    @State private var changedPhoto = false
    @State private var isSaving = false
    @State private var didLoadFields = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    AccountSettingsHeader(title: "Edit Profile", subtitle: "Your neighborhood identity") {
                        dismiss()
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
                        title: "Verified account",
                        message: "Your phone number comes from SMS sign-in and cannot be changed here. Name and neighborhood are saved to your account."
                    )
                    AccountSaveStatus(error: photoError ?? viewModel.errorMessage, success: viewModel.successMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            PrimaryButton(
                title: isSaving ? "Saving..." : "Save profile",
                enabled: !viewModel.isLoading && !isSaving && didLoadFields
            ) {
                Task { await save() }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(AppTheme.surface)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task {
            await load()
        }
        .onChange(of: selectedPhoto) { _, selection in
            Task {
                do {
                    guard let data = try await selection?.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let jpeg = image.jpegData(compressionQuality: 0.72) else { return }
                    photoData = jpeg
                    changedPhoto = true
                    photoError = nil
                } catch {
                    photoError = error.localizedDescription
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
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 39))
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
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

    private func load() async {
        await viewModel.loadProfile(using: dependencies.accountRepository)
        if let account = viewModel.account {
            displayName = account.displayName
            neighborhood = account.neighborhood
            phoneNumber = account.phoneNumber
            photoData = account.photoData
        }
        didLoadFields = true
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        photoError = nil
        defer { isSaving = false }

        let saved = await viewModel.saveProfile(
            displayName: displayName,
            neighborhood: neighborhood,
            phoneNumber: phoneNumber,
            using: dependencies.accountRepository
        )
        guard saved else { return }

        if changedPhoto, let photoData {
            do {
                try await dependencies.accountRepository.updateProfilePhoto(photoData)
            } catch {
                photoError = error.localizedDescription
                return
            }
        }

        try? await Task.sleep(nanoseconds: 350_000_000)
        dismiss()
    }
}
