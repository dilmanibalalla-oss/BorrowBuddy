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
    @State private var profileOverride: AccountSummary?
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
                        DismissingErrorText(message: message, size: 12.5)
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
                    EditProfileView(startingAccount: shownAccount) { saved in
                        profileOverride = saved
                        dependencies.editedAccount = saved
                        viewModel.apply(saved, cache: dependencies.offlineCache)
                        if path.count > 0 {
                            path.removeLast()
                        }
                    }
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
            if let saved = dependencies.editedAccount {
                viewModel.apply(saved, cache: dependencies.offlineCache)
            }
            await loadListings()
        }
        .onChange(of: path.count) { _, newCount in
            // Returning from Edit Profile / settings — refresh so Firestore values show.
            if newCount == 0 {
                Task {
                    await viewModel.load(using: dependencies.accountRepository, cache: dependencies.offlineCache)
                    if let saved = dependencies.editedAccount {
                        viewModel.apply(saved, cache: dependencies.offlineCache)
                    }
                    await loadListings()
                }
            }
        }
        .onChange(of: dependencies.editedAccount) { _, saved in
            guard let saved else { return }
            viewModel.apply(saved, cache: dependencies.offlineCache)
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

    private var shownAccount: AccountSummary {
        guard let saved = profileOverride ?? dependencies.editedAccount else { return viewModel.account }
        let current = viewModel.account
        return AccountSummary(
            displayName: saved.displayName,
            neighborhood: saved.neighborhood,
            phoneNumber: saved.phoneNumber.isEmpty ? current.phoneNumber : saved.phoneNumber,
            creditBalance: current.creditBalance == 0 ? saved.creditBalance : current.creditBalance,
            creditHeld: current.creditHeld,
            photoData: saved.photoData ?? current.photoData,
            latitude: current.latitude ?? saved.latitude,
            longitude: current.longitude ?? saved.longitude,
            streetAddress: current.streetAddress.isEmpty ? saved.streetAddress : current.streetAddress,
            unit: current.unit.isEmpty ? saved.unit : current.unit,
            postalCode: current.postalCode.isEmpty ? saved.postalCode : current.postalCode,
            identityVerified: current.identityVerified || saved.identityVerified,
            addressConfirmed: current.addressConfirmed || saved.addressConfirmed,
            isPro: current.isPro || saved.isPro
        )
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
                        if let data = shownAccount.photoData, let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(AppTheme.blue)
                        }
                    }
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(shownAccount.displayName)
                        .font(AppTheme.rounded(18, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    if !shownAccount.neighborhood.isEmpty {
                        Label(shownAccount.neighborhood, systemImage: "mappin.circle.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(AppTheme.green)
                    } else if !shownAccount.streetAddress.isEmpty {
                        Label(shownAccount.streetAddress, systemImage: "mappin.circle.fill")
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
                VStack(spacing: 8) {
                    Text("No shared tools yet")
                        .font(.system(size: 12.5))
                        .foregroundStyle(AppTheme.green)
                }
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
                                .accessibilityHidden(true)
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
                    .accessibilityLabel("\(tool.name), \(tool.dailyCredits) credits a day")
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
                menuRow("Notification Preferences", icon: "bell", destination: .notifications)
                Divider()
                darkModeRow
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
                profileOverride = nil
                dependencies.editedAccount = nil
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
