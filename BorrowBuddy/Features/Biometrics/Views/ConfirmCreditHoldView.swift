//
//  ConfirmCreditHoldView.swift
//  BorrowBuddy
//

import LocalAuthentication
import SwiftUI

struct ConfirmCreditHoldView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var viewModel = CreditHoldConfirmationViewModel()

    private var tool: BorrowingTool { flow.selectedTool }
    private var quote: ReservationQuote { flow.quote }

    var body: some View {
        VStack(spacing: 18) {
            LoanHeader(title: "Confirm hold", subtitle: "Authorize with Face ID") {
                router.go(to: .reservationReview)
            }

            Text("\(quote.totalHold) LC will move into a refundable hold for \(tool.name).")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.green)
                .frame(maxWidth: .infinity, alignment: .leading)

            AccountSaveStatus(error: viewModel.errorMessage, success: nil)

            ThemeClipart(name: "ClipartSafe", height: 180, label: "Neighbors confirming a borrow")
            Spacer(minLength: 12)

            PrimaryButton(
                title: viewModel.isLoading ? "Authorizing..." : "Authorize with Face ID",
                enabled: !viewModel.isLoading
            ) {
                Task {
                    if let reservation = await viewModel.authorize(
                        policy: .deviceOwnerAuthenticationWithBiometrics,
                        repository: dependencies.borrowingRepository,
                        tool: tool,
                        quote: quote
                    ) {
                        flow.reservation = reservation
                        router.go(to: .reservationPending)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.background)
    }
}
