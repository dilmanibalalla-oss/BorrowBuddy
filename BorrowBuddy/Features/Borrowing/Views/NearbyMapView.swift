import MapKit
import SwiftUI

struct NearbyMapView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var viewModel = NearbyMapViewModel()
    @StateObject private var account = AccountViewModel()
    @State private var visibleCamera: MapCamera?
    @State private var hasUserAdjustedCamera = false
    @State private var hiddenMapError: String?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: BorrowingTool.demo.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )
    )

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Map")
                        .font(AppTheme.rounded(23, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                    Spacer()
                    Text("\(account.account.creditBalance) LC")
                        .font(AppTheme.rounded(13, weight: .bold))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.horizontal, 14)
                        .frame(height: 31)
                        .overlay {
                            Capsule().stroke(AppTheme.blue, lineWidth: 2)
                        }
                }

                HStack(spacing: 11) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(AppTheme.blue)
                    TextField("Search tools, cameras, gear", text: $viewModel.searchText)
                        .font(.system(size: 15))
                    Menu {
                        Picker("Search radius", selection: $viewModel.radiusKilometers) {
                            ForEach([1.0, 5.0, 10.0, 50.0], id: \.self) { Text("\(Int($0)) km").tag($0) }
                        }
                        Toggle("Show all available tools", isOn: $viewModel.showsAllLocations)
                        Button("Set saved location") { router.go(to: .savedLocation) }
                        Button("Refresh tools") { Task { await reloadMap() } }
                    } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(AppTheme.blue) }
                }
                .padding(.horizontal, 13)
                .frame(height: 45)
                .overlay {
                    Rectangle().stroke(AppTheme.blue, lineWidth: 1.5)
                }
                .padding(.top, 35)

                Text("Available Tools Map")
                    .font(AppTheme.rounded(22, weight: .heavy))
                    .foregroundStyle(AppTheme.blue)
                    .padding(.top, 23)

                Text(viewModel.resultSummary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.green)
            }
            .padding(.horizontal, 11)
            .padding(.top, 16)

            GeometryReader { proxy in
                let width = proxy.size.width
                if isPadWidth(width) {
                    HStack(spacing: 0) {
                        toolList
                            .frame(width: toolColumnWidth(width))
                            .frame(maxHeight: .infinity)
                        mapStage(showsPreviewCard: false)
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    mapStage(showsPreviewCard: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.top, 10)
            AccountSaveStatus(error: account.errorMessage.map { "Account: \($0)" }, success: nil)

            BorrowingTabBar(
                selectedTab: 1,
                onHome: { router.go(to: .home) },
                onSearch: {},
                onCalendar: { router.go(to: .calendar) },
                onProfile: { router.go(to: .profile) }
            )
        }
        .background(AppTheme.background)
        .ignoresSafeArea(.container, edges: .bottom)
        .task { await reloadMap() }
        .onChange(of: viewModel.filteredTools.map(\.id)) { _, _ in
            if !hasUserAdjustedCamera { fitVisibleTools() }
        }
        .onChange(of: viewModel.searchText) { _, _ in fitVisibleTools() }
        .onChange(of: viewModel.showsAllLocations) { _, _ in fitVisibleTools() }
        .onChange(of: viewModel.radiusKilometers) { oldRadius, newRadius in
            guard oldRadius != newRadius else { return }
            viewModel.showsAllLocations = false
            fitVisibleTools()
        }
        .onChange(of: dependencies.savedShedCoordinate?.latitude) { _, _ in
            applySavedShed(recenter: true)
        }
    }

    /// Portrait widths: iPad mini (A17 Pro) 744, iPad (A16) and 11-inch iPad Air 820, 13-inch iPad Air 1024.
    private func isPadWidth(_ width: CGFloat) -> Bool {
        horizontalSizeClass == .regular && width >= 700
    }

    private func toolColumnWidth(_ width: CGFloat) -> CGFloat {
        min(400, max(260, floor(width * 0.34)))
    }

    private func mapStage(showsPreviewCard: Bool) -> some View {
        ZStack(alignment: .top) {
            Map(position: $position, interactionModes: .all) {
                if let origin = viewModel.origin {
                    Marker("Your shed", coordinate: origin)
                        .tint(AppTheme.yellow)
                }
                ForEach(viewModel.filteredTools) { tool in
                    Annotation(tool.name, coordinate: tool.coordinate) {
                        Button { flow.select(tool); router.go(to: .toolDetails) } label: {
                          Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.red)
                            .background(Circle().fill(Color.white).frame(width: 12, height: 12))
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .continuous) { context in
                visibleCamera = context.camera
                if position.positionedByUser { hasUserAdjustedCamera = true }
            }
            .overlay(alignment: .trailing) {
                mapNavigationControls.padding(.trailing, 12)
            }
            .overlay(alignment: .bottom) {
                mapStatus
                    .padding(12)
                    .padding(.bottom, 24)
            }

            if showsPreviewCard, let tool = viewModel.filteredTools.first {
                Button {
                    flow.select(tool)
                    router.go(to: .toolDetails)
                } label: {
                    HStack(spacing: 11) {
                        CatalogToolArtwork(tool: tool)
                            .frame(width: 62, height: 62)
                            .background(Color(red: 0.91, green: 0.90, blue: 0.86))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(tool.name)
                                .font(AppTheme.rounded(15, weight: .bold))
                                .foregroundStyle(AppTheme.blue)
                            Text("From \(tool.ownerName)")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.green)
                        }

                        Spacer()
                        StatusPill(title: "Available", filled: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.surface)
                    .overlay {
                        Rectangle().stroke(AppTheme.border, lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(tool.name), from \(tool.ownerName)")
                .padding(.horizontal, 5)
                .padding(.top, 11)
            }
        }
    }

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tools")
                .font(AppTheme.rounded(18, weight: .heavy))
                .foregroundStyle(AppTheme.blue)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    if viewModel.filteredTools.isEmpty && !viewModel.isLoading {
                        Text("No tools match this search.")
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(viewModel.filteredTools) { tool in
                        Button {
                            flow.select(tool)
                            router.go(to: .toolDetails)
                        } label: {
                            HStack(spacing: 10) {
                                CatalogToolArtwork(tool: tool)
                                    .frame(width: 52, height: 52)
                                    .background(Color(red: 0.91, green: 0.90, blue: 0.86))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tool.name)
                                        .font(AppTheme.rounded(15, weight: .bold))
                                        .foregroundStyle(AppTheme.blue)
                                        .lineLimit(1)
                                    Text(toolListDetail(tool))
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(AppTheme.green)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1.5)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(tool.name). \(toolListDetail(tool))")
                        .accessibilityHint("Opens this tool.")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .padding(.top, 4)
        .background(AppTheme.background)
        .overlay(alignment: .trailing) {
            Rectangle().fill(AppTheme.border).frame(width: 1)
        }
    }

    private func toolListDetail(_ tool: BorrowingTool) -> String {
        let owner = "From \(tool.ownerName)"
        guard let meters = viewModel.distance(to: tool) else { return "\(owner) · \(tool.dailyCredits) LC/day" }
        return String(format: "%@ · %.1f km · %d LC/day", owner, meters / 1000, tool.dailyCredits)
    }

    private var mapNavigationControls: some View {
        VStack(spacing: 0) {
            Button { zoom(zoomingIn: true) } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Zoom in")
            Divider().frame(width: 30)
            Button { zoom(zoomingIn: false) } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Zoom out")
            Divider().frame(width: 30)
            Button { fitVisibleTools() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Show tools on map")
            .disabled(viewModel.filteredTools.isEmpty && viewModel.origin == nil)
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(AppTheme.blue)
        .buttonStyle(.plain)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1) }
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
    }

    private func zoom(zoomingIn: Bool) {
        // Change only altitude: keep the user's current center, heading and pitch.
        var camera = visibleCamera ?? position.camera ?? MapCamera(
            centerCoordinate: viewModel.origin ?? BorrowingTool.demo.coordinate,
            distance: 5_000
        )
        camera.distance = MapZoomPolicy.distance(from: camera.distance, zoomingIn: zoomingIn)
        hasUserAdjustedCamera = true
        visibleCamera = camera
        withAnimation(.easeInOut(duration: 0.2)) { position = .camera(camera) }
    }

    @ViewBuilder
    private var mapStatus: some View {
        if viewModel.isLoading {
            ProgressView("Loading tools…")
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        } else if let error = viewModel.errorMessage, hiddenMapError != error {
            statusCard("Unable to load tools", detail: FriendlyError.clean(error)) {
                Button("Retry") { Task { await reloadMap() } }
            }
            .task(id: error) {
                try? await Task.sleep(for: .seconds(3))
                hiddenMapError = error
            }
        } else if let emptyState = viewModel.emptyState {
            switch emptyState {
            case .outsideRadius:
                statusCard("No tools within \(Int(viewModel.radiusKilometers)) km", detail: "Available listings match your search, but are outside the radius of your saved location.") {
                    Button("Show all available tools") { viewModel.showsAllLocations = true }
                    Button("Change saved location") { router.go(to: .savedLocation) }
                }
            case .noSearchMatches:
                statusCard("No matching tools", detail: "Try a different tool name or category.") {
                    Button("Clear search") { viewModel.searchText = "" }
                }
            case .noListings:
                statusCard("No available listings yet", detail: "Only available tools appear here. Reserved or removed tools are not shown.") {
                    Button("Home → List a tool") { router.go(to: .home) }
                    Button("Refresh tools") { Task { await reloadMap() } }
                }
            }
        }
    }

    private func statusCard<Actions: View>(_ title: String, detail: String,
                                         @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppTheme.rounded(16, weight: .bold)).foregroundStyle(AppTheme.blue)
            Text(detail).font(.system(size: 13)).foregroundStyle(AppTheme.text)
            VStack(alignment: .leading, spacing: 10, content: actions)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.blue)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 1) }
    }

    private func reloadMap() async {
        applySavedShed(recenter: !hasUserAdjustedCamera)
        async let accountLoad: Void = account.load(using: dependencies.accountRepository, cache: dependencies.offlineCache)
        async let toolsLoad: Void = viewModel.load(using: dependencies.borrowingRepository, cache: dependencies.offlineCache)
        _ = await (accountLoad, toolsLoad)
        guard !Task.isCancelled else { return }
        if dependencies.savedShedCoordinate == nil,
           let latitude = account.account.latitude, let longitude = account.account.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            if CLLocationCoordinate2DIsValid(coordinate) {
                dependencies.savedShedCoordinate = coordinate
            }
        }
        applySavedShed(recenter: !hasUserAdjustedCamera)
    }

    private func applySavedShed(recenter: Bool) {
        if let saved = dependencies.savedShedCoordinate, CLLocationCoordinate2DIsValid(saved) {
            viewModel.origin = saved
        } else if let latitude = account.account.latitude, let longitude = account.account.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            viewModel.origin = CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        } else {
            viewModel.origin = nil
        }
        guard recenter else { return }
        fitVisibleTools()
    }

    private func fitVisibleTools() {
        hasUserAdjustedCamera = false
        if !viewModel.showsAllLocations, let origin = viewModel.origin {
            let delta = max(0.02, viewModel.radiusKilometers / 55)
            withAnimation(.easeInOut(duration: 0.35)) {
                position = .region(MKCoordinateRegion(
                    center: origin,
                    span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)
                ))
            }
            return
        }
        let tools = viewModel.filteredTools
        guard !tools.isEmpty else {
            if let origin = viewModel.origin {
                let delta = max(0.025, viewModel.radiusKilometers / 45)
                position = .region(MKCoordinateRegion(center: origin,
                    span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)))
            }
            return
        }
        let latitudes = tools.map(\.latitude)
        let longitudes = tools.map(\.longitude)
        let minLatitude = latitudes.min() ?? 0
        let maxLatitude = latitudes.max() ?? 0
        let minLongitude = longitudes.min() ?? 0
        let maxLongitude = longitudes.max() ?? 0
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.05, (maxLatitude - minLatitude) * 1.6),
            longitudeDelta: max(0.05, (maxLongitude - minLongitude) * 1.6)
        )
        position = .region(MKCoordinateRegion(center: center, span: span))
    }
}
