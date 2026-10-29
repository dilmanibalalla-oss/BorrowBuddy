//
//  ProfileView.swift
//  BorrowBuddy
//

import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = AccountViewModel()
    @State private var path = NavigationPath()
    @State private var errorMessage: String?
    @State private var myListings: [BorrowingTool] = []
    @AppStorage(AppTheme.darkModeKey) private var darkMode = false

    var body: some View {
        VStack(spacing: 0) {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    profileHeader
                    profileCard
                    listings
                    accountMenu
                    logoutButton
                    if let message = errorMessage ?? viewModel.errorMessage {
                        Text(message)
                            .font(.system(size: 12.5))
                            .foregroundStyle(AppTheme.coral)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
            .refreshable {
                await viewModel.load(using: dependencies.accountRepository, cache: dependencies.offlineCache)
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
            .navigationDestination(for: AccountDestination.self) { destination in
                switch destination {
                case .editProfile:
                    EditProfileView()
                case .notifications:
                    NotificationPreferencesView()
                case .paymentMethods:
                    PaymentMethodsView()
                case .wallet:
                    WalletView()
                case .creditTopUp:
                    CreditTopUpView()
                case .loanProtection:
                    LoanProtectionView()
                case .identityVerification:
                    IdentityVerificationView()
                }
            }
        }
        .task {
            await viewModel.load(using: dependencies.accountRepository, cache: dependencies.offlineCache)
            await loadListings()
        }
        .onChange(of: path.count) { _, newCount in
            // Returning from Edit Profile / settings — refresh so Firestore values show.
            if newCount == 0 {
                Task {
                    await viewModel.load(using: dependencies.accountRepository, cache: dependencies.offlineCache)
                    await loadListings()
                }
            }
        }
        BorrowingTabBar(
            selectedTab: 3,
            onHome: { router.go(to: .home) },
            onSearch: { router.go(to: .nearbyMap) },
            onCalendar: { router.go(to: .calendar) },
            onProfile: {}
        )
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var profileHeader: some View {
        HStack {
            Text("My Profile")
                .font(AppTheme.rounded(23, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            Spacer()
            Text("\(viewModel.account.creditBalance) LC")
                .font(AppTheme.rounded(13, weight: .bold))
                .foregroundStyle(AppTheme.blue)
                .padding(.horizontal, 13)
                .frame(height: 31)
                .overlay { Capsule().stroke(AppTheme.blue, lineWidth: 2) }
        }
    }

    private var profileCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppTheme.yellow.opacity(0.45))
                    .frame(width: 64, height: 64)
                    .overlay {
                        if let data = viewModel.account.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.account.displayName)
                        .font(AppTheme.rounded(18, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    if !viewModel.account.neighborhood.isEmpty {
                        Label(viewModel.account.neighborhood, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.green)
                    } else if !viewModel.account.streetAddress.isEmpty {
                        Label(viewModel.account.streetAddress, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.green)
                    }
                }
                Spacer()
            }

            HStack {
                Label("Neighborhood Share Score", systemImage: "star")
                Spacer()
                Text("0 LC")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(AppTheme.blue)
            .padding(.horizontal, 14)
            .frame(height: 43)
            .background(AppTheme.blue.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(18)
        .background(AppTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 1)
        }
    }

    private var listings: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("My Listings")
                .font(AppTheme.rounded(15, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
            if myListings.isEmpty {
                Text("No shared tools yet")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(AppTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15).stroke(AppTheme.border, lineWidth: 1)
                    }
            } else {
                ForEach(myListings) { tool in
                    Button {
                        dependencies.borrowingFlow.select(tool)
                        router.go(to: .toolDetails)
                    } label: {
                        HStack(spacing: 12) {
                            CatalogToolArtwork(tool: tool)
                                .frame(width: 52, height: 52)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.name)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.blue)
                                Text("\(tool.dailyCredits) LC/day")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 15).stroke(AppTheme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func loadListings() async {
        guard let userID = dependencies.authenticationService.currentUserID else {
            myListings = []
            return
        }
        let tools = (try? await dependencies.borrowingRepository.fetchNearbyTools()) ?? []
        myListings = tools
            .filter { $0.ownerID == userID }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    private var accountMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account")
                .font(AppTheme.rounded(15, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            VStack(spacing: 0) {
                menuRow("Edit Profile", icon: "person", destination: .editProfile)
                Divider()
                menuRow("Wallet", icon: "creditcard.fill", destination: .wallet)
                Divider()
                menuRow(
                    viewModel.account.identityVerified ? "Identity verified" : "Identity Verification",
                    icon: "person.text.rectangle",
                    destination: .identityVerification
                )
                Divider()
                menuRow("Notification Preferences", icon: "bell", destination: .notifications)
                Divider()
                darkModeRow
                Divider()
                menuRow("Payment Methods", icon: "creditcard", destination: .paymentMethods)
                Divider()
                menuRow("Loan Protection", icon: "checkmark.shield", destination: .loanProtection)
            }
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 15).stroke(AppTheme.border, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
        }
    }

    private var darkModeRow: some View {
        HStack(spacing: 13) {
            Image(systemName: darkMode ? "moon.fill" : "sun.max.fill")
                .foregroundStyle(AppTheme.blue)
                .frame(width: 20)
            Text("Dark mode")
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.text)
            Spacer()
            Toggle("Dark mode", isOn: $darkMode)
                .labelsHidden()
                .tint(AppTheme.blue)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dark mode")
        .accessibilityValue(darkMode ? "On" : "Off")
    }

    private func menuRow(_ title: String, icon: String, destination: AccountDestination) -> some View {
        Button {
            path.append(destination)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.blue)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.border)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }

    private var logoutButton: some View {
        Button {
            do {
                try dependencies.authenticationService.signOut()
                router.go(to: .signUp)
            } catch {
                errorMessage = error.localizedDescription
            }
        } label: {
            Text("Log Out")
                .font(AppTheme.rounded(14, weight: .bold))
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .contentShape(Rectangle())
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AppTheme.coral, lineWidth: 2)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(.plain)
    }
}
