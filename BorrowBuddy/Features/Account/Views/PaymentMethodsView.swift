//
//  PaymentMethodsView.swift
//  BorrowBuddy
//

import SwiftUI

struct PaymentMethodsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountSettingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    AccountSettingsHeader(title: "Payment Methods", subtitle: "StoreKit 2 purchases") {
                        dismiss()
                    }
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppTheme.blue.opacity(0.10))
                            .frame(width: 50, height: 42)
                            .overlay {
                                Image(systemName: "bag")
                                    .font(.system(size: 20))
                                    .foregroundStyle(AppTheme.blue)
                            }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("App Store · StoreKit 2")
                                .font(AppTheme.rounded(15, weight: .bold))
                                .foregroundStyle(AppTheme.text)
                            Text("LendCredit packs and BorrowBuddy Pro are bought in the app. No card is stored here.")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 21))
                            .foregroundStyle(AppTheme.blue)
                    }
                    .padding(14)
                    .background(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppTheme.blue, lineWidth: 1.5)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    AccountNotice(
                        icon: "lock.shield",
                        title: "Apple verifies the payment",
                        message: "StoreKit 2 checks each transaction on this device. BorrowBuddy only records the LendCredits after that check succeeds."
                    )
                    AccountSaveStatus(error: viewModel.errorMessage, success: viewModel.successMessage)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            PrimaryButton(
                title: viewModel.isLoading ? "Saving..." : "Save StoreKit preference",
                enabled: !viewModel.isLoading
            ) {
                viewModel.paymentMethod = "StoreKit 2"
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
            viewModel.paymentMethod = "StoreKit 2"
            await viewModel.loadPaymentMethod(using: dependencies.accountRepository)
            if viewModel.paymentMethod != "StoreKit 2" {
                viewModel.paymentMethod = "StoreKit 2"
            }
        }
    }
}
