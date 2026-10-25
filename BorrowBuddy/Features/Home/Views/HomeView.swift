import SwiftUI
import CoreLocation

struct HomeView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var model = CommunityViewModel()
    @State private var showToolEditor = false

    private var activeRental: ReservationRecord? {
        model.loans.first { $0.isOpen && $0.borrowerID == dependencies.authenticationService.currentUserID }
            ?? model.loans.first(where: \.isOpen)
    }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(spacing: 13) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(greeting).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.green)
                                Text("Hey, \(model.account.displayName.isEmpty ? "Neighbor" : model.account.displayName.components(separatedBy: " ").first ?? model.account.displayName)")
                                    .font(AppTheme.rounded(25, weight: .heavy)).foregroundStyle(AppTheme.blue)
                            }
                            Spacer()
                            Button("\(model.account.creditBalance) LC") { router.go(to: .wallet) }
                                .font(AppTheme.rounded(13, weight: .bold)).foregroundStyle(AppTheme.blue)
                                .padding(.horizontal, 13).padding(.vertical, 7).overlay(Capsule().stroke(AppTheme.blue, lineWidth: 2))
                        }
                        HStack(spacing: 12) {
                            Button { showToolEditor = true } label: {
                                Text("+ List a tool").font(AppTheme.rounded(16, weight: .heavy)).foregroundStyle(.white)
                                    .frame(maxWidth: .infinity).frame(height: 48).background(AppTheme.blue).clipShape(RoundedRectangle(cornerRadius: 11))
                            }.buttonStyle(.plain)
                            LoanOutlineButton(title: "Find a tool") { router.go(to: .nearbyMap) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        Button { router.go(to: .loanList) } label: { heading("Active rental") }.buttonStyle(.plain).accessibilityLabel("Active rental and loan history")
                        if let loan = activeRental {
                            Button { dependencies.open(loan, router: router) } label: { rentalCard(loan) }.buttonStyle(.plain)
                        } else {
                            LoanCard { Text(model.sectionErrors["Loan history"] == nil ? "No active rental yet" : "Unable to load rentals. Pull down to retry.").font(.system(size: 13)).foregroundStyle(AppTheme.green).frame(minHeight: 62) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        heading("Featured near you")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(model.nearbyTools.prefix(5)) { tool in
                                    Button {
                                        dependencies.borrowingFlow.select(tool); router.go(to: .toolDetails)
                                    } label: { featured(tool) }.buttonStyle(.plain)
                                }
                            }
                        }
                        if model.nearbyTools.isEmpty && !model.isLoading {
                            Text(model.sectionErrors["Nearby tools"] == nil ? "No nearby tools available yet" : "Unable to load nearby tools. Pull down to retry.").font(.system(size: 12.5)).foregroundStyle(AppTheme.green)
                        }
                    }
                    if !recentlyAdded.isEmpty {
                        VStack(alignment: .leading, spacing: 11) {
                            heading("Recently added")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentlyAdded.prefix(5)) { tool in
                                        Button {
                                            dependencies.borrowingFlow.select(tool); router.go(to: .toolDetails)
                                        } label: { featured(tool) }.buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        heading("Recent activity")
                        ForEach(model.ledger.prefix(2)) { entry in
                            HStack(spacing: 9) {
                                Circle().fill(entry.credits >= 0 ? AppTheme.green : AppTheme.coral).frame(width: 8, height: 8)
                                Text(entry.detail.isEmpty ? entry.title : entry.detail).font(.system(size: 14)).foregroundStyle(AppTheme.text).lineLimit(1)
                                Spacer()
                                if entry.kind == .credit {
                                    Text("\(entry.credits >= 0 ? "+" : "")\(entry.credits) LC").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(entry.credits >= 0 ? AppTheme.green : AppTheme.coral)
                                } else {
                                    Text(entry.kind == .pickup ? "Pickup" : "Return").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppTheme.blue)
                                }
                            }.padding(12).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        if model.ledger.isEmpty && !model.isLoading { Text(model.sectionErrors["Wallet activity"] == nil ? "No recent activity" : "Unable to load activity. Pull down to retry.").font(.system(size: 12.5)).foregroundStyle(AppTheme.green) }
                    }
                    AccountSaveStatus(error: model.error, success: nil)
                    if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 18)
            }.refreshable { await refreshHome() }
            BorrowingTabBar(selectedTab: 0, onHome: {}, onSearch: { router.go(to: .nearbyMap) },
                            onCalendar: { router.go(to: .calendar) }, onProfile: { router.go(to: .profile) })
        }.background(AppTheme.background).ignoresSafeArea(.container, edges: .bottom)
            .task { await refreshHome() }
            .sheet(isPresented: $showToolEditor, onDismiss: { Task { await refreshHome() } }) {
                ToolEditorView(tool: nil).environmentObject(dependencies)
            }
    }

    private func heading(_ value: String) -> some View {
        Text(value).font(AppTheme.rounded(16, weight: .heavy)).foregroundStyle(AppTheme.blue)
    }
    private func rentalCard(_ loan: ReservationRecord) -> some View {
        let duration = max(1, loan.returnAt.timeIntervalSince(loan.pickupAt))
        let progress = min(1, max(0, Date().timeIntervalSince(loan.pickupAt) / duration))
        return LoanCard {
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    CatalogToolArtwork(tool: loan.toolSnapshot).frame(width: 52, height: 49)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(loan.toolName) · due \(loan.returnAt.formatted(.dateTime.weekday(.wide)))")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(AppTheme.blue)
                        Text(loan.borrowerID == dependencies.authenticationService.currentUserID ? "Borrowed from \(loan.ownerName)" : "Lent to \(loan.borrowerName)")
                            .font(.system(size: 12.5)).foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.blue.opacity(0.12))
                        Capsule().fill(AppTheme.blue).frame(width: proxy.size.width * progress)
                    }
                }.frame(height: 8)
            }.padding(3)
        }
    }
    private func featured(_ tool: BorrowingTool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CatalogToolArtwork(tool: tool).frame(width: 138, height: 98)
            Text(tool.name).font(AppTheme.rounded(14, weight: .bold)).foregroundStyle(AppTheme.blue).lineLimit(1)
            Text(featureDetail(tool)).font(.system(size: 12)).foregroundStyle(AppTheme.secondaryText)
        }.padding(11).frame(width: 162, alignment: .leading).background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var recentlyAdded: [BorrowingTool] {
        model.nearbyTools.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }
    private func featureDetail(_ tool: BorrowingTool) -> String {
        guard let latitude = model.account.latitude, let longitude = model.account.longitude else { return "\(tool.dailyCredits) LC/day" }
        let meters = CLLocation(latitude: latitude, longitude: longitude).distance(from: CLLocation(latitude: tool.latitude, longitude: tool.longitude))
        return String(format: "%.1f mi · %d LC", meters / 1609.344, tool.dailyCredits)
    }
    private func refreshHome() async {
        await model.load(using: dependencies)
        let preferences = (try? await dependencies.accountRepository.loadNotificationSettings()) ?? .standard
        for loan in model.loans {
            await dependencies.notificationService.schedule(for: loan, preferences: preferences)
        }
        await dependencies.notificationService.watchLoanMessages(model.loans)
    }
}
