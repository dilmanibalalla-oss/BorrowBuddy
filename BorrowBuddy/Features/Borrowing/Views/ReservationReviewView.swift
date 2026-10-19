//
//  ReservationReviewView.swift
//  BorrowBuddy
//

import SwiftUI

struct ReservationReviewView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var viewModel = ReservationReviewViewModel()

    private var tool: BorrowingTool { flow.selectedTool }
    private var quote: ReservationQuote { flow.quote }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    LoanHeader(
                        title: "Review hold",
                        subtitle: "Confirm dates before authorizing credits"
                    ) {
                        router.go(to: .toolDetails)
                    }

                    LoanCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(tool.name)
                                .font(AppTheme.rounded(18, weight: .heavy))
                                .foregroundStyle(AppTheme.blue)
                            BorrowingInfoRow(label: "Pickup", value: quote.pickupAt.borrowingDateTime, icon: "calendar")
                            BorrowingInfoRow(label: "Return", value: quote.returnAt.borrowingDateTime, icon: "clock")
                            BorrowingInfoRow(label: "Rental", value: "\(quote.rentalCredits) LC")
                            BorrowingInfoRow(label: "Service", value: "\(quote.serviceCredits) LC")
                            BorrowingInfoRow(label: "Deposit", value: "\(quote.depositCredits) LC")
                            BorrowingInfoRow(label: "Total hold", value: "\(quote.totalHold) LC")
                        }
                    }

                    AccountSaveStatus(error: viewModel.errorMessage, success: nil)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            }

            PrimaryButton(
                title: viewModel.isLoading ? "Authorizing..." : "Authorize \(quote.totalHold) LC hold",
                enabled: !viewModel.isLoading
            ) {
                Task {
                    if let reservation = await viewModel.authorize(
                        repository: dependencies.borrowingRepository,
                        tool: tool,
                        quote: quote
                    ) {
                        flow.reservation = reservation
                        router.go(to: .reservationPending)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
            .background(Color.white)
        }
        .background(AppTheme.background)
    }
}
