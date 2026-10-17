//
//  LocationSetupView.swift
//  BorrowBuddy
//

import SwiftUI

struct LocationSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies

    @State private var street = ""
    @State private var apt = ""
    @State private var city = ""
    @State private var stateZip = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canConfirm: Bool {
        !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !stateZip.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isSaving
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Find Your Shed")
                    .font(AppTheme.rounded(28, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.top, 24)

                Text("Set your home base so we can show tools nearby.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.top, 8)

                PrimaryButton(title: "Use My Location") {
                    // Placeholder until Core Location permissions are wired.
                    street = "123 Maple Street"
                    city = "Your City"
                    stateZip = "CA 90210"
                }
                .padding(.top, 28)

                AuthTextField(
                    title: "Street Address",
                    placeholder: "123 Maple Street",
                    text: $street,
                    kind: .street
                )
                .padding(.top, 22)

                AuthTextField(
                    title: "Apt / Unit",
                    placeholder: "Optional",
                    text: $apt,
                    kind: .unit
                )
                .padding(.top, 14)

                AuthTextField(
                    title: "City",
                    placeholder: "City",
                    text: $city,
                    kind: .city
                )
                .padding(.top, 14)

                AuthTextField(
                    title: "State / Zip",
                    placeholder: "CA 90210",
                    text: $stateZip,
                    kind: .postal
                )
                .padding(.top, 14)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.coral)
                        .padding(.top, 14)
                }

                PrimaryButton(
                    title: isSaving ? "Saving..." : "Confirm Location",
                    enabled: canConfirm
                ) {
                    Task { await confirmLocation() }
                }
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background)
    }

    private func confirmLocation() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            try await dependencies.authenticationService.completeOnboarding()
            router.go(to: .home)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
