//
//  PhoneSignInView.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-17.
//

import SwiftUI
import UIKit

struct PhoneSignInView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = PhoneSignInViewModel()
    @State private var showCountryPicker = false
    @State private var focusTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton {
                router.go(to: .signUp)
            }
            .padding(.top, 8)
            .padding(.leading, -18)

            Spacer()

            Text("Welcome, Neighbor!")
                .font(AppTheme.rounded(28, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            Text("Join BorrowBuddy. Enter your phone number\nto get verified.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .padding(.top, 7)

            Text("PHONE NUMBER")
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.top, 28)

            HStack(spacing: 12) {
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
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Country code, \(viewModel.selectedCountry.name)")

                Rectangle()
                    .fill(AppTheme.border)
                    .frame(width: 1, height: 28)

                RespondableTextField(
                    text: Binding(
                        get: { viewModel.phoneNumber },
                        set: viewModel.format
                    ),
                    placeholder: "11 234 5678",
                    keyboardType: .numberPad,
                    textContentType: .telephoneNumber,
                    filterDigitsOnly: false,
                    focusTrigger: focusTrigger
                )
                .frame(maxWidth: .infinity)
                .frame(height: 22)
                .accessibilityLabel("Phone number")
            }
            .padding(.horizontal, 15)
            .frame(height: 54)
            .background(Color.white)
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

            Text("By continuing, you agree to receive a single automated SMS\nverification code. Carrier rates may apply.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
                .padding(.top, 17)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.coral)
                    .padding(.top, 12)
            }

            Spacer()

            PrimaryButton(
                title: viewModel.isLoading ? "Sending..." : "Send Verification Code",
                enabled: viewModel.canContinue && !viewModel.isLoading
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
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
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
                            .font(.system(size: 28))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(country.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.blue)
                            Text(country.displayDialCode)
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        if country == selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                }
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
