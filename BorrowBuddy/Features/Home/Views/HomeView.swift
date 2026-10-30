import SwiftUI
import CoreLocation

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var model = CommunityViewModel()
    @State private var showToolEditor = false
    @State private var shedWeather: ShedWeather?

    private var activeRental: ReservationRecord? {
        model.loans.first { $0.isOpen && $0.borrowerID == dependencies.authenticationService.currentUserID }
            ?? model.loans.first(where: \.isOpen)
    }
    private var profileFirstName: String {
        let saved = dependencies.editedAccount?.displayName ?? ""
        let loaded = model.account.displayName
        let name = saved.isEmpty ? loaded : saved
        if name.isEmpty { return "Neighbor" }
        return name.components(separatedBy: " ").first ?? name
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening"
    }

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let wide = isPadWidth(width)
                let horizontalPadding: CGFloat = width >= 1000 ? 32 : wide ? 24 : 20
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        homeHeader
                        if wide {
                            padHomeContent(contentWidth: width - horizontalPadding * 2)
                        } else {
                            phoneHomeContent
                        }
                        AccountSaveStatus(error: model.error, success: nil)
                        if model.isLoading { ProgressView().frame(maxWidth: .infinity) }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .refreshable { await refreshHome() }
            }
            BorrowingTabBar(selectedTab: 0, onHome: {}, onSearch: { router.go(to: .nearbyMap) },
                            onCalendar: { router.go(to: .calendar) }, onProfile: { router.go(to: .profile) })
        }.background(AppTheme.background).ignoresSafeArea(.container, edges: .bottom)
            .task { await refreshHome() }
            .sheet(isPresented: $showToolEditor, onDismiss: { Task { await refreshHome() } }) {
                ToolEditorView(tool: nil).environmentObject(dependencies)
            }
    }

    private var homeHeader: some View {
        VStack(spacing: 13) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting).font(.system(size: 13, weight: .semibold)).foregroundStyle(AppTheme.green)
                    Text("Hey, \(profileFirstName)")
                        .font(AppTheme.rounded(25, weight: .heavy)).foregroundStyle(AppTheme.blue)
                    if let shedWeather {
                        Text(shedWeather.summary)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .accessibilityLabel(shedWeather.summary)
                    }
                }
                Spacer()
                Button {
                    router.go(to: .messages)
                } label: {
                    Image(systemName: "message")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppTheme.blue, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Messages")
                .accessibilityHint("Opens your loan messages.")
                Button("\(model.account.creditBalance) LC") { router.go(to: .wallet) }
                    .font(AppTheme.rounded(13, weight: .bold)).foregroundStyle(AppTheme.blue)
                    .padding(.horizontal, 13).padding(.vertical, 7).overlay(Capsule().stroke(AppTheme.blue, lineWidth: 2))
            }
            HStack(spacing: 12) {
                Button { showToolEditor = true } label: {
                    Text("+ List a tool").font(AppTheme.rounded(16, weight: .heavy)).foregroundStyle(AppTheme.onBlue)
                        .frame(maxWidth: .infinity).frame(height: 48).background(AppTheme.blue).clipShape(RoundedRectangle(cornerRadius: 11))
                }.buttonStyle(.plain)
                LoanOutlineButton(title: "Find a tool") { router.go(to: .nearbyMap) }
            }
        }
    }

    /// iPad mini (A17 Pro) is 744pt wide in portrait. iPad (A16) and 11-inch iPad Air are 820. 13-inch iPad Air is 1024.
    private func isPadWidth(_ width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 700
    }

    private var phoneHomeContent: some View {
        VStack(alignment: .leading, spacing: 22) {
            activeRentalSection
            featuredSection(contentWidth: 0, wide: false)
            recentlyAddedSection(contentWidth: 0, wide: false)
            recentActivitySection
        }
    }

    private func padHomeContent(contentWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            if contentWidth >= 860 {
                HStack(alignment: .top, spacing: 24) {
                    activeRentalSection
                        .frame(maxWidth: .infinity, alignment: .leading)
                    recentActivitySection
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                activeRentalSection
                recentActivitySection
            }
            featuredSection(contentWidth: contentWidth, wide: true)
            recentlyAddedSection(contentWidth: contentWidth, wide: true)
        }
    }

    private var activeRentalSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                heading("Active rental")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Loan history") { router.go(to: .loanList) }
                    .font(AppTheme.rounded(13, weight: .bold))
                    .foregroundStyle(AppTheme.blue)
                    .accessibilityHint("Opens your loans.")
            }
            if let loan = activeRental {
                rentalCard(loan)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(rentalSummary(loan))
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityRemoveTraits(.isButton)
            } else {
                LoanCard { Text(model.sectionErrors["Loan history"] == nil ? "No active rental yet" : "Unable to load rentals. Pull down to retry.").font(.system(size: 13)).foregroundStyle(AppTheme.green).frame(minHeight: 62) }
            }
        }
    }

    private func featuredSection(contentWidth: CGFloat, wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            heading("Featured near you")
                .accessibilityAddTraits(.isHeader)
            toolCards(featuredNearby.prefix(5), contentWidth: contentWidth, wide: wide)
            if model.nearbyTools.isEmpty && !model.isLoading {
                Text(model.sectionErrors["Nearby tools"] == nil ? "No nearby tools available yet" : "Unable to load nearby tools. Pull down to retry.").font(.system(size: 12.5)).foregroundStyle(AppTheme.green)
            }
        }
    }

    @ViewBuilder
    private func recentlyAddedSection(contentWidth: CGFloat, wide: Bool) -> some View {
        if !recentlyAdded.isEmpty {
            VStack(alignment: .leading, spacing: 11) {
                heading("Recently added")
                    .accessibilityAddTraits(.isHeader)
                toolCards(recentlyAdded.prefix(5), contentWidth: contentWidth, wide: wide)
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 11) {
            heading("Recent activity")
                .accessibilityAddTraits(.isHeader)
            ForEach(model.ledger.prefix(2)) { entry in
                HStack(spacing: 9) {
                    Circle().fill(entry.credits >= 0 ? AppTheme.green : AppTheme.coral).frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(entry.detail.isEmpty ? entry.title : entry.detail).font(.system(size: 14)).foregroundStyle(AppTheme.text).lineLimit(1)
                    Spacer()
                    if entry.kind == .credit {
                        Text("\(entry.credits >= 0 ? "+" : "")\(entry.credits) LC").font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(entry.credits >= 0 ? AppTheme.green : AppTheme.coral)
                    } else {
                        Text(entry.kind == .pickup ? "Pickup" : "Return").font(.system(size: 12.5, weight: .bold)).foregroundStyle(AppTheme.blue)
                    }
                }
                .padding(12).background(AppTheme.surface).clipShape(RoundedRectangle(cornerRadius: 13))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityRemoveTraits(.isButton)
            }
            if model.ledger.isEmpty && !model.isLoading { Text(model.sectionErrors["Wallet activity"] == nil ? "No recent activity" : "Unable to load activity. Pull down to retry.").font(.system(size: 12.5)).foregroundStyle(AppTheme.green) }
        }
    }

    @ViewBuilder
    private func toolCards(_ tools: some RandomAccessCollection<BorrowingTool>, contentWidth: CGFloat, wide: Bool) -> some View {
        if wide {
            LazyVGrid(columns: padColumns(contentWidth), alignment: .leading, spacing: 12) {
                ForEach(tools) { tool in
                    toolCard(tool, fillsWidth: true)
                }
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tools) { tool in
                        toolCard(tool, fillsWidth: false)
                    }
                }
            }
        }
    }

    private func padColumns(_ contentWidth: CGFloat) -> [GridItem] {
        let count = contentWidth >= 1100 ? 4 : contentWidth >= 860 ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .leading), count: count)
    }

    private func toolCard(_ tool: BorrowingTool, fillsWidth: Bool) -> some View {
        Button {
            dependencies.borrowingFlow.select(tool)
            router.go(to: .toolDetails)
        } label: {
            featured(tool, fillsWidth: fillsWidth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tool.name). \(featureDetail(tool))")
        .accessibilityHint("Opens this tool.")
        .accessibilityAddTraits(.isButton)
    }

    private func rentalSummary(_ loan: ReservationRecord) -> String {
        let who = loan.borrowerID == dependencies.authenticationService.currentUserID
            ? "Borrowed from \(loan.ownerName)"
            : "Lent to \(loan.borrowerName)"
        return "\(loan.toolName), due \(loan.returnAt.formatted(.dateTime.weekday(.wide))). \(who)"
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
    private func featured(_ tool: BorrowingTool, fillsWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            CatalogToolArtwork(tool: tool)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .frame(width: fillsWidth ? nil : 138, height: 98)
            Text(tool.name).font(AppTheme.rounded(14, weight: .bold)).foregroundStyle(AppTheme.blue).lineLimit(1)
            Text(featureDetail(tool)).font(.system(size: 12)).foregroundStyle(AppTheme.secondaryText)
        }
        .padding(11)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        .frame(width: fillsWidth ? nil : 162, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var featuredNearby: [BorrowingTool] {
        guard let latitude = model.account.latitude, let longitude = model.account.longitude else {
            return model.nearbyTools
        }
        let origin = CLLocation(latitude: latitude, longitude: longitude)
        return model.nearbyTools.sorted {
            origin.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < origin.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
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
        if let latitude = model.account.latitude, let longitude = model.account.longitude {
            shedWeather = try? await ShedWeatherService.current(latitude: latitude, longitude: longitude)
        } else {
            shedWeather = nil
        }
        await dependencies.accountRepository.syncBorrowingBlock(for: model.loans)
        let preferences = (try? await dependencies.accountRepository.loadNotificationSettings()) ?? .standard
        for loan in model.loans {
            await dependencies.notificationService.schedule(for: loan, preferences: preferences)
        }
        await dependencies.notificationService.watchLoanMessages(model.loans)
    }
}
