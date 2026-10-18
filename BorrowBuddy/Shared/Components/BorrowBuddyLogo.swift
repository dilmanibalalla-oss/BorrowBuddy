//
//  BorrowBuddyLogo.swift
//  BorrowBuddy
//

import SwiftUI

struct BorrowBuddyLogo: View {
    var size: CGFloat = 140

    var body: some View {
        let corner: CGFloat = size * 0.157
        let stripeHeight: CGFloat = size * 0.12
        let iconSize: CGFloat = size * 0.29
        let tagWidth: CGFloat = size * 0.4
        let tagHeight: CGFloat = size * 0.157

        ZStack {
            RoundedRectangle(cornerRadius: corner)
                .fill(AppTheme.shadow)
                .frame(width: size, height: size)
                .offset(y: size * 0.05)

            RoundedRectangle(cornerRadius: corner)
                .fill(AppTheme.yellow)
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: corner)
                        .stroke(AppTheme.blue, lineWidth: 4)
                }

            Rectangle()
                .fill(AppTheme.blue)
                .frame(width: size - 4, height: stripeHeight)

            Image(systemName: "wrench.adjustable")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(AppTheme.blue)
                .offset(x: size * 0.064, y: -size * 0.136)

            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.blue, lineWidth: 4)
                .frame(width: tagWidth, height: tagHeight)
                .offset(x: -size * 0.3, y: -size * 0.57)
        }
        .frame(width: size * 1.18, height: size * 1.23)
        .accessibilityHidden(true)
    }
}
