//
//  CreditTopUpView.swift
//  BorrowBuddy
//

import SwiftUI

struct CreditTopUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPack = CreditPack.builder
    @State private var statusMessage: String?

    private var total: Decimal { selectedPack.price }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 13) {
                    header
                    packCard(.starter, recommended: false)
                    packCard(.builder, recommended: true)
                    AccountNotice(
                        icon: "lock.shield",
                        title: "Secure hosted checkout",
                        message: "Credits are added only after the payment provider confirms payment. No card details are stored in BorrowBuddy."
                    )
                    if let statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.green)
                    }
                    PrimaryButton(title: "Pay Securely ($\(formatted(total)))") {
                        statusMessage = "Checkout will open here once payment is connected. Your \(selectedPack.title) selection is ready."
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Top-Up Credits")
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                Text("BUY SECURE WORKSHOP TOKENS")
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
        }
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
                            .foregroundStyle(AppTheme.blue)
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
                Text("$\(formatted(pack.price))")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(pack == selectedPack ? AppTheme.green : AppTheme.blue)
            }
            .padding(15)
            .frame(minHeight: recommended ? 90 : 72)
            .background(Color.white)
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
    }

    private func formatted(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        return number.stringValue.contains(".") ? number.stringValue : number.stringValue + ".00"
    }
}
