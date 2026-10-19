//
//  WalletView.swift
//  BorrowBuddy
//

import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AccountViewModel()
    @State private var showTopUp = false

    var body: some View {
        VStack(spacing: 0) {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                AccountSettingsHeader(
                    title: "LendCredit Wallet",
                    subtitle: "Neighborhood tokens"
                ) {
                    if router.route == .wallet {
                        router.go(to: .home)
                    } else {
                        dismiss()
                    }
                }
                balanceCard
                ledger
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.coral)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .refreshable { await viewModel.load(using: dependencies.accountRepository) }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $showTopUp) {
            CreditTopUpView()
        }
        .task {
            await viewModel.load(using: dependencies.accountRepository)
        }
        if router.route == .wallet {
            BorrowingTabBar(
                selectedTab: 2,
                onHome: { router.go(to: .home) },
                onSearch: { router.go(to: .nearbyMap) },
                onWallet: {},
                onProfile: { router.go(to: .profile) }
            )
        }
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text("CURRENT BALANCE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Spacer()
                Image(systemName: "shield")
                    .foregroundStyle(AppTheme.yellow)
            }
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(viewModel.account.creditBalance)")
                    .font(AppTheme.rounded(48, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Text("LendCredits (LC)")
                    .font(AppTheme.rounded(17, weight: .bold))
                    .foregroundStyle(AppTheme.green)
            }
            if viewModel.account.creditHeld > 0 {
                Text("\(viewModel.account.creditHeld) LC currently held for reservations")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
            }
            PrimaryButton(title: "Top-Up Credits", systemImage: "bolt.fill") {
                showTopUp = true
            }
        }
        .padding(20)
        .background(Color.white)
        .overlay {
            RoundedRectangle(cornerRadius: 18).stroke(AppTheme.blue, lineWidth: 2.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: AppTheme.shadow, radius: 0, x: 0, y: 6)
    }

    private var ledger: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Transaction Ledger")
                .font(AppTheme.rounded(15, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            VStack(spacing: 0) {
                if viewModel.ledger.isEmpty && !viewModel.isLoading {
                    Text("No wallet activity yet")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 70)
                } else {
                    ForEach(Array(viewModel.ledger.enumerated()), id: \.element.id) { index, entry in
                        walletRow(entry)
                        if index < viewModel.ledger.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .background(Color.white)
            .overlay {
                RoundedRectangle(cornerRadius: 14).stroke(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func walletRow(_ entry: WalletEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text(entry.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(entry.credits > 0 ? "+\(entry.credits) LC" : "\(entry.credits) LC")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(entry.credits >= 0 ? AppTheme.green : AppTheme.coral)
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
    }
}
