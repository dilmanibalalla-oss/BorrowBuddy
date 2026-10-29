//
//  LoanProtectionView.swift
//  BorrowBuddy
//

import SwiftUI

struct LoanProtectionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                AccountSettingsHeader(
                    title: "Loan Protection",
                    subtitle: "If a borrowed item is not returned"
                ) {
                    dismiss()
                }

                hero
                timelineCard
                evidenceCard
                AccountNotice(
                    icon: "person.2.badge.gearshape",
                    title: "Human review is required",
                    message: "Photo similarity and location signals never automatically accuse a borrower or apply a charge. A fair review uses the complete evidence timeline."
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationBarHidden(true)
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(AppTheme.blue)
            Text("Your loan is protected")
                .font(AppTheme.rounded(21, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            Text("A clear grace period, evidence receipt, and fair review process protect both neighbors.")
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.green)
                .padding(.horizontal, 22)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(AppTheme.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var timelineCard: some View {
        AccountCard {
            VStack(alignment: .leading, spacing: 15) {
                Text("Non-return response plan")
                    .font(AppTheme.rounded(15, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                step("1", "Before due", "Return reminders at 24 hours and 2 hours.")
                step("2", "24-hour grace", "Both people can message or agree to an extension.")
                step("3", "Borrowing paused", "New requests stop while an overdue loan is unresolved.")
                step("4", "7-day escalation", "Evidence, communication, and any appeal are reviewed.")
            }
        }
    }

    private var evidenceCard: some View {
        AccountCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Protection technology")
                    .font(AppTheme.rounded(15, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                technology("map", "MapKit", "Pickup and return-area confirmation")
                technology("calendar", "EventKit", "Private return reminders")
                technology("viewfinder", "Apple Vision", "Eight pickup/return photo comparisons")
            }
        }
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Text(number)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.onBlue)
                .frame(width: 26, height: 26)
                .background(AppTheme.blue)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
            }
        }
    }

    private func technology(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.blue)
                .frame(width: 34, height: 34)
                .background(AppTheme.blue.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.green)
            }
        }
    }
}
