//
//  CreditTopUpView.swift
//  BorrowBuddy
//

import StoreKit
import SwiftUI

struct CreditTopUpView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StorePurchaseService()
    @State private var selectedPack = CreditPack.builder
    @State private var statusMessage: String?
    @State private var isPurchasing = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    header
                    packCard(.starter, recommended: false)
                    packCard(.builder, recommended: true)
                    proCard
                    AccountNotice(
                        icon: "lock.shield",
                        title: "StoreKit 2 checkout",
                        message: "LendCredit packs and BorrowBuddy Pro are purchased with StoreKit 2. Apple verifies the transaction on this device. BorrowBuddy does not collect a card number."
                    )
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.green)
                    }
                    PrimaryButton(
                        title: isPurchasing ? "Contacting the App Store..." : "Buy \(selectedPack.title)",
                        enabled: !isPurchasing
                    ) {
                        Task { await buy(selectedPack) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
        .task { await store.loadProducts() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Top-Up Credits")
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Text("STOREKIT 2 LENDCREDIT PACKS")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.green)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var proCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BORROWBUDDY PRO")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(AppTheme.onYellow)
                .padding(.horizontal, 5)
                .frame(height: 17)
                .background(AppTheme.yellow)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text("Monthly membership")
                .font(AppTheme.rounded(15, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            Text("Borrow more than one tool at a time and receive a one-time \(MembershipPolicy.proWelcomeCredits) LendCredit welcome pack.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.secondaryText)
            Text(proPrice)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.green)
            PrimaryButton(title: isPurchasing ? "Contacting the App Store..." : "Subscribe with StoreKit 2", enabled: !isPurchasing) {
                Task { await buyPro() }
            }
        }
        .padding(15)
        .background(AppTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 15).stroke(AppTheme.blue, lineWidth: 1.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }

    private func packCard(_ pack: CreditPack, recommended: Bool) -> some View {
        Button {
            selectedPack = pack
            statusMessage = nil
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    if recommended {
                        Text("BEST VALUE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(AppTheme.onYellow)
                            .padding(.horizontal, 5)
                            .frame(height: 17)
                            .background(AppTheme.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(pack.title)
                        .font(AppTheme.rounded(15, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    Text("Receive \(pack.credits) LendCredits")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Text(priceLabel(for: pack))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(pack == selectedPack ? AppTheme.green : AppTheme.blue)
            }
            .padding(15)
            .frame(minHeight: recommended ? 90 : 72)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(
                        pack == selectedPack ? AppTheme.yellow : AppTheme.border,
                        lineWidth: pack == selectedPack ? 2.5 : 1.5
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .shadow(color: pack == selectedPack ? AppTheme.shadow : .clear, radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pack.title), \(pack.credits) LendCredits")
    }

    private var proPrice: String {
        store.product(id: StoreCatalog.proMonthlyProductID)?.displayPrice ?? "$4.99 / month"
    }

    private func priceLabel(for pack: CreditPack) -> String {
        if let product = store.product(id: pack.productID) {
            return product.displayPrice
        }
        return "$\(formatted(pack.price))"
    }

    private func buy(_ pack: CreditPack) async {
        guard let product = store.product(id: pack.productID) else {
            statusMessage = StorePurchaseError.unavailable.localizedDescription
            return
        }
        await purchase(product) { transaction in
            try await dependencies.accountRepository.recordStorePurchase(
                transactionID: String(transaction.id),
                productID: product.id,
                credits: pack.credits,
                title: pack.title,
                detail: "StoreKit 2 purchase"
            )
            statusMessage = "Added \(pack.credits) LendCredits."
        }
    }

    private func buyPro() async {
        guard let product = store.product(id: StoreCatalog.proMonthlyProductID) else {
            statusMessage = StorePurchaseError.unavailable.localizedDescription
            return
        }
        await purchase(product) { transaction in
            try await dependencies.accountRepository.activateProMembership(transactionID: String(transaction.id))
            statusMessage = "BorrowBuddy Pro is active. \(MembershipPolicy.proWelcomeCredits) welcome LendCredits were added once."
        }
    }

    private func purchase(_ product: Product, apply: (StoreKit.Transaction) async throws -> Void) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let transaction = try await store.purchase(product)
            try await apply(transaction)
            await store.finish(transaction)
        } catch let error as StorePurchaseError where error == .cancelled {
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func formatted(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return number.stringValue.contains(".") ? number.stringValue : number.stringValue + ".00"
    }
}
