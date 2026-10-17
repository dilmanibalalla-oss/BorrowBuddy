//
//  DashboardView.swift
//  BorrowBuddy
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var selectedTab = 0

    private var firstName: String {
        let name = dependencies.authenticationService.currentDisplayName ?? "Neighbor"
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case 0:
                    homeContent
                case 1:
                    placeholder(title: "Search", systemImage: "magnifyingglass")
                case 2:
                    placeholder(title: "Messages", systemImage: "bubble.left.and.bubble.right")
                default:
                    profileContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            HStack {
                tabItem(0, "house.fill", "Home")
                tabItem(1, "magnifyingglass", "Search")
                tabItem(2, "bubble.left.and.bubble.right.fill", "Messages")
                tabItem(3, "person.fill", "Profile")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(Color.white)
        }
        .background(AppTheme.cardBackground.ignoresSafeArea())
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hey, \(firstName).")
                            .font(AppTheme.rounded(28, weight: .heavy))
                            .foregroundStyle(AppTheme.blue)
                        Text("Your neighborhood shed is open.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Text("12 credits")
                        .font(AppTheme.rounded(13, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.yellow.opacity(0.35))
                        .clipShape(Capsule())
                }
                .padding(.top, 8)

                HStack(spacing: 10) {
                    segmentChip("Lending", selected: true)
                    segmentChip("Borrowed", selected: false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Active tools")
                        .font(AppTheme.rounded(18, weight: .bold))
                        .foregroundStyle(AppTheme.blue)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(AppTheme.green)
                            Text("Lawn-mower")
                                .font(AppTheme.rounded(16, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Text("2d left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        ProgressView(value: 0.65)
                            .tint(AppTheme.yellow)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Featured near you")
                        .font(AppTheme.rounded(18, weight: .bold))
                        .foregroundStyle(AppTheme.blue)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.yellow.opacity(0.25))
                                .frame(width: 72, height: 72)
                            Image(systemName: "hammer.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.blue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Cordless Drill")
                                .font(AppTheme.rounded(16, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("0.4 mi · 3 credits / day")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent activity")
                        .font(AppTheme.rounded(18, weight: .bold))
                        .foregroundStyle(AppTheme.blue)

                    activityRow(title: "Returned hedge trimmer", subtitle: "Yesterday")
                    activityRow(title: "Borrowed ladder from Sam", subtitle: "Mon")
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var profileContent: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.blue)
            Text(dependencies.authenticationService.currentDisplayName ?? "Neighbor")
                .font(AppTheme.rounded(22, weight: .bold))
                .foregroundStyle(AppTheme.blue)

            PrimaryButton(title: "Sign out") {
                try? dependencies.authenticationService.signOut()
                router.go(to: .signUp)
            }
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func placeholder(title: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.blue)
            Text(title)
                .font(AppTheme.rounded(22, weight: .bold))
                .foregroundStyle(AppTheme.blue)
        }
    }

    private func tabItem(_ index: Int, _ systemImage: String, _ label: String) -> some View {
        Button {
            selectedTab = index
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(selectedTab == index ? AppTheme.blue : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func segmentChip(_ title: String, selected: Bool) -> some View {
        Text(title)
            .font(AppTheme.rounded(14, weight: .semibold))
            .foregroundStyle(selected ? AppTheme.blue : AppTheme.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.yellow : Color.white)
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(AppTheme.border, lineWidth: selected ? 0 : 1)
            }
    }

    private func activityRow(title: String, subtitle: String) -> some View {
        HStack {
            Circle()
                .fill(AppTheme.yellow.opacity(0.4))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.text)
            Spacer()
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
