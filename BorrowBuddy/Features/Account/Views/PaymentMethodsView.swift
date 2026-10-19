//
//  PaymentMethodsView.swift
//  BorrowBuddy
//

import PassKit
import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountSettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AccountSettingsHeader(title: "Payment Methods", subtitle: "Secure credit top-ups") {
                        dismiss()
                    }
                    paymentCard(
                        title: "Apple Pay (checkout option)",
                        detail: PKPaymentAuthorizationViewController.canMakePayments()
                            ? "When supported by the secure checkout"
                            : "Set up a card in Apple Wallet",
                        icon: "apple.logo",
                        value: "Apple Pay"
                    )
                    paymentCard(
                        title: "Secure card checkout",
                        detail: "Add a card in hosted checkout; no card details saved here",
                        icon: "creditcard",
                        value: "Payment provider"
                    )
                    AccountNotice(
                        icon: "lock.shield",
                        title: "Your card details stay private",
                        message: "BorrowBuddy stores only this preference, not a payment card. Available methods are determined by the provider at checkout."
                    )
                    AccountSaveStatus(error: viewModel.errorMessage, success: viewModel.successMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            PrimaryButton(
                title: viewModel.isLoading ? "Saving..." : "Save payment preference",
                enabled: !viewModel.isLoading
            ) {
                Task {
                    _ = await viewModel.savePaymentMethod(using: dependencies.accountRepository)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task {
            await viewModel.loadPaymentMethod(using: dependencies.accountRepository)
        }
    }

    private func paymentCard(
        title: String,
        detail: String,
        icon: String,
        value: String,
        enabled: Bool = true
    ) -> some View {
        Button {
            if enabled {
                viewModel.paymentMethod = value
            }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.blue.opacity(0.10))
                    .frame(width: 50, height: 42)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.blue)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTheme.rounded(15, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Image(systemName: viewModel.paymentMethod == value ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(enabled ? AppTheme.blue : AppTheme.border)
            }
            .padding(14)
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(viewModel.paymentMethod == value ? AppTheme.blue : AppTheme.border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
