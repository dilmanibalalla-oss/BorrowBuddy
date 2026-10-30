//
//  BorrowBuddyLogo.swift
//  BorrowBuddy
//

import SwiftUI

struct BorrowBuddyLogo: View {
    var size: CGFloat = 140

    var body: some View {
        Image("BorrowBuddyLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
