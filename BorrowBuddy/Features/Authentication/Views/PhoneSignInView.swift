//
//  PhoneSignInView.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import SwiftUI

struct PhoneSignInView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = PhoneSignInViewModel()
    @State private var showCountryPicker = false
    @State private var focusTrigger = 0

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .signUp)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            signInArtwork(width: proxy.size.width)
                .padding(.top, 8)

            Spacer()

            Text("Welcome, Neighbor!")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .accessibilityAddTraits(.isHeader)

            Text("Join BorrowBuddy. Enter your phone number\nto get verified.")
                .font(AppTheme.system(16))
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .padding(.top, 7)

            Text("PHONE NUMBER")
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 28)

            HStack(alignment: .center, spacing: 12) {
                Button {
                    showCountryPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(viewModel.selectedCountry.flag)
                            .font(.system(size: 22))
                        Text(viewModel.selectedCountry.displayDialCode)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .accessibilityHidden(true)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Country code, \(viewModel.selectedCountry.name), \(viewModel.selectedCountry.displayDialCode)")
                .accessibilityHint("Opens the country list.")

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 28)
                    .accessibilityHidden(true)

                RespondableTextField(
                    text: Binding(
                        get: { viewModel.phoneNumber },
                        set: viewModel.format
                    ),
                    placeholder: "11 234 5678",
                    keyboardType: .numberPad,
                    textContentType: .telephoneNumber,
                    font: .systemFont(ofSize: 16, weight: .semibold),
                    filterDigitsOnly: false,
                    focusTrigger: focusTrigger,
                    accessibilityLabelText: "Phone number",
                    scalesWithDynamicType: false
                )
                .frame(maxWidth: .infinity)
                .frame(height: 22)
            }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.blue, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
            .onTapGesture {
                focusTrigger += 1
            }
            .padding(.top, 7)

            Text("No text is sent. Tap continue,\nthen enter code \(DevAuthFixtures.testVerificationCode).")
                .font(AppTheme.system(12.5))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .padding(.top, 17)

            if let errorMessage = viewModel.errorMessage {
                DismissingErrorText(message: errorMessage, topPadding: 12)
            }

            Spacer()

            PrimaryButton(
                title: viewModel.isLoading ? "Sending..." : "Send Verification Code",
                enabled: viewModel.canContinue && !viewModel.isLoading,
                accessibilityHint: "Continues to the verification code."
            ) {
                Task {
                    if let verificationID = await viewModel.sendCode(
                        using: dependencies.authenticationService
                    ) {
                        dependencies.verificationID = verificationID
                        dependencies.verificationPhoneNumber = viewModel.displayPhoneNumber
                        router.go(to: .verification)
                    }
                }
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: proxy.size.height)
        }
        .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .accessibilityAnnounce(viewModel.errorMessage)
        .sheet(isPresented: $showCountryPicker, onDismiss: {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusTrigger += 1
            }
        }) {
            CountryPickerView(selected: viewModel.selectedCountry) { country in
                viewModel.selectCountry(country)
                showCountryPicker = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focusTrigger += 1
            }
        }
    }

    private func signInArtwork(width: CGFloat) -> some View {
        let wide = width >= 700
        let artWidth = wide ? min(width - 48, 460) : min(max(width - 48, 160), 320)
        let artHeight = wide ? 260.0 : 180.0
        return Image("SignInArtwork")
            .resizable()
            .scaledToFit()
            .frame(width: artWidth, height: artHeight)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Neighbor browsing shared tools")
            .accessibilityAddTraits(.isImage)
    }
}

private struct CountryPickerView: View {
    let selected: Country
    let onSelect: (Country) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Country] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Country.all }
        return Country.all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.dialCode.contains(trimmed)
                || $0.id.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { country in
                Button {
                    onSelect(country)
                } label: {
                    HStack(spacing: 12) {
                        Text(country.flag)
                            .font(AppTheme.system(28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(AppTheme.system(16, weight: .semibold))
                                .foregroundStyle(AppTheme.blue)
                            Text(country.displayDialCode)
                                .font(AppTheme.system(13))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        if country == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.blue)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel("\(country.name), \(country.displayDialCode)")
                .accessibilityAddTraits(country == selected ? .isSelected : AccessibilityTraits())
                .listRowBackground(AppTheme.background)
            }
            .searchable(text: $query, prompt: "Search country")
            .navigationTitle("Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .background(AppTheme.background)
        }
        .presentationDetents([.medium, .large])
    }
}
