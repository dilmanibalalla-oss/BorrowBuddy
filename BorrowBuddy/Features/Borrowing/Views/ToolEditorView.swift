import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ToolEditorView: View {
    let tool: BorrowingTool?
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category = "Power Tools"
    @State private var condition = "Good"
    @State private var details = ""
    @State private var pickupAddress = ""
    @State private var dailyCredits = 8
    @State private var depositCredits = 20
    @State private var availableFrom = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var availableUntil = Calendar.current.date(byAdding: .day, value: 14, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let categories = ["Power Tools", "Garden", "Home", "Outdoor", "Other"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tool == nil ? "List a tool" : "Edit listing")
                        .font(AppTheme.rounded(25, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AppTheme.blue.opacity(0.06))
                                .frame(height: 140)
                            if let photoData, let image = UIImage(data: photoData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 140)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            } else {
                                Label("Add a photo", systemImage: "camera")
                                    .foregroundStyle(AppTheme.blue)
                            }
                        }
                    }
                    field("Tool name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    field("Condition", text: $condition)
                    field("Pickup address", text: $pickupAddress)
                    field("Details", text: $details)
                    DatePicker("Available from", selection: $availableFrom, in: Date()..., displayedComponents: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                    DatePicker("Available until", selection: $availableUntil, in: availableFrom..., displayedComponents: .date)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .onChange(of: availableFrom) { _, from in
                            if availableUntil < from { availableUntil = from }
                        }
                    Stepper("Daily price: \(dailyCredits) LC", value: $dailyCredits, in: 1...200)
                    Stepper("Deposit: \(depositCredits) LC", value: $depositCredits, in: 0...500)
                    AccountSaveStatus(error: errorMessage, success: nil)
                    PrimaryButton(title: isSaving ? "Saving..." : "Publish listing", enabled: canSave && !isSaving) {
                        Task { await save() }
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    guard let item else { return }
                    do {
                        if let photo = try await item.loadTransferable(type: ListingPhoto.self) {
                            photoData = photo.data
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .onAppear {
                if let tool {
                    name = tool.name
                    category = tool.category
                    condition = tool.condition
                    details = tool.details
                    pickupAddress = tool.pickupAddress
                    dailyCredits = tool.dailyCredits
                    depositCredits = tool.depositCredits
                    photoData = tool.photoData
                    if let from = tool.availableFrom { availableFrom = from }
                    if let until = tool.availableUntil { availableUntil = until }
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Calendar.current.startOfDay(for: availableUntil) >= Calendar.current.startOfDay(for: availableFrom)
    }

    private func field(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.blue)
            TextField(title, text: text)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(Color.white)
                .overlay { RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 1.5) }
        }
    }

    private func save() async {
        guard !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let account = try await dependencies.accountRepository.loadAccount()
            guard let latitude = account.latitude, let longitude = account.longitude, latitude != 0 || longitude != 0 else {
                throw CommunityError.invalidInput("Set your saved location before listing a tool.")
            }
            let ownerID = dependencies.authenticationService.currentUserID ?? ""
            guard !ownerID.isEmpty else { throw CommunityError.signInRequired }
            let listing = BorrowingTool(
                id: tool?.id ?? "",
                ownerID: ownerID,
                ownerName: account.displayName.isEmpty ? (dependencies.authenticationService.currentDisplayName ?? "Neighbor") : account.displayName,
                ownerRating: tool?.ownerRating ?? 0,
                ownerLoanCount: tool?.ownerLoanCount ?? 0,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                condition: condition.trimmingCharacters(in: .whitespacesAndNewlines),
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                dailyCredits: dailyCredits,
                depositCredits: depositCredits,
                latitude: latitude,
                longitude: longitude,
                pickupAddress: pickupAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                imageURL: tool?.imageURL,
                isHighValue: depositCredits >= 100,
                estimatedValue: tool?.estimatedValue ?? dailyCredits * 10,
                photoData: photoData,
                listingStatus: "available",
                availableFrom: availableFrom,
                availableUntil: availableUntil
            )
            let listingID: String
            if tool == nil || listing.id.isEmpty {
                listingID = try await dependencies.borrowingRepository.addTool(listing)
            } else {
                try await dependencies.borrowingRepository.updateTool(listing)
                listingID = listing.id
            }
            try? await dependencies.eventReminderService.addListingWindow(
                toolID: listingID,
                name: listing.name,
                from: availableFrom,
                until: availableUntil
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ListingPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            guard let image = UIImage(data: data) else {
                throw CommunityError.invalidInput("Choose a photo of the tool.")
            }
            return ListingPhoto(data: try PhotoEncoding.jpeg(image))
        }
    }
}
