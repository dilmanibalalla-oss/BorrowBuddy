import _LocationEssentials
import MapKit
import SwiftUI

struct NearbyMapView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var flow: BorrowingFlowStore
    @StateObject private var viewModel = NearbyMapViewModel()
    @StateObject private var account = AccountViewModel()
    @State private var visibleCamera: MapCamera?
    @State private var hasUserAdjustedCamera = false
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

            ZStack(alignment: .top) {
                Map(position: $position, interactionModes: .all) {
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

                if let tool = viewModel.filteredTools.first {
                    Button {
                        flow.select(tool)
                        router.go(to: .toolDetails)
                    } label: {
                        HStack(spacing: 11) {
                            CatalogToolArtwork(tool: tool)
                                .frame(width: 62, height: 62)
                                .background(Color(red: 0.91, green: 0.90, blue: 0.86))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

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
                        .background(Color.white)
                        .overlay {
                            Rectangle().stroke(AppTheme.border, lineWidth: 1.5)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 5)
                    .padding(.top, 11)
                }
            }
            .padding(.top, 10)
            AccountSaveStatus(error: account.errorMessage.map { "Account: \($0)" }, success: nil)

            BorrowingTabBar(
                selectedTab: 1,
                onHome: { router.go(to: .home) },
                onSearch: {},
                onWallet: { router.go(to: .wallet) },
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
        .onChange(of: viewModel.radiusKilometers) { _, _ in
            viewModel.showsAllLocations = false
            fitVisibleTools()
        }
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
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
        } else if let error = viewModel.errorMessage {
            statusCard("Unable to load tools", detail: error) {
                Button("Retry") { Task { await reloadMap() } }
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
        async let accountLoad: Void = account.load(using: dependencies.accountRepository)
        async let toolsLoad: Void = viewModel.load(using: dependencies.borrowingRepository)
        _ = await (accountLoad, toolsLoad)
        guard !Task.isCancelled else { return }
        if let latitude = account.account.latitude, let longitude = account.account.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            viewModel.origin = CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
        } else { viewModel.origin = nil }
        // Loading fresh listings must not undo a user's pinch, drag or button zoom.
        if !hasUserAdjustedCamera { fitVisibleTools() }
    }

    private func fitVisibleTools() {
        hasUserAdjustedCamera = false
        if !viewModel.filteredTools.isEmpty {
            // Fit actual annotation coordinates rather than keeping a stale saved-location camera.
            position = .automatic
        } else if let origin = viewModel.origin {
            let delta = max(0.025, viewModel.radiusKilometers / 45)
            position = .region(MKCoordinateRegion(center: origin,
                span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)))
        }
    }
}

