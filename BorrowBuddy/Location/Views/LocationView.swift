import MapKit
import SwiftUI

struct LocationView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var viewModel = LocationViewModel()
    @StateObject private var model = CommunityViewModel()
    @State private var mapPosition: MapCameraPosition = .automatic

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            BackButton { router.go(to: .home) }
                .padding(.bottom, 30)

            Text("Find Your Shed")
                .font(AppTheme.rounded(27, weight: .heavy))
                .foregroundStyle(AppTheme.blue)

            Text("Set your location to find nearby shared tools. Use your current location, or type your address. Your profile address is private; each listing has its own pickup address.")
                .font(.system(size: 15.5))
                .foregroundStyle(AppTheme.text)
                .lineSpacing(4)
                .padding(.top, 7)

            Button {
                viewModel.useCurrentLocation()
            } label: {
                HStack(spacing: 10) {
                    Image("Location")
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 18, height: 22)

                    Text("Use My Location")
                        .font(AppTheme.rounded(16, weight: .bold))
                }
                .foregroundStyle(AppTheme.onYellow)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AppTheme.yellow)
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AppTheme.onYellow, lineWidth: 2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .shadow(color: AppTheme.shadow, radius: 0, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use My Location")
            .padding(.top, 28)

            if !viewModel.locationStatus.isEmpty {
                Text(viewModel.locationStatus)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 9)
            }

            shedMap
                .padding(.top, 16)

            HStack(spacing: 12) {
                Rectangle().fill(AppTheme.border).frame(height: 1)
                Text("OR")
                    .font(AppTheme.rounded(13, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryText)
                Rectangle().fill(AppTheme.border).frame(height: 1)
            }
            .padding(.top, 34)

            fieldLabel("STREET ADDRESS")
                .padding(.top, 28)

            addressField("Street, town, country", text: $viewModel.streetAddress)

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("UNIT / APT")
                    addressField("Optional", text: $viewModel.unit)
                }

                VStack(alignment: .leading, spacing: 7) {
                    fieldLabel("POSTAL CODE")
                    addressField("Postal code", text: $viewModel.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            .padding(.top, 13)

            Spacer(minLength: 30)

            AccountSaveStatus(error: model.error, success: nil)
            PrimaryButton(title: model.isLoading ? "Saving..." : "Confirm Location", enabled: viewModel.canContinue && !model.isLoading) {
                Task { await confirmLocation() }
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.background)
        .task {
            do {
                let account = try await dependencies.accountRepository.loadAccount()
                viewModel.streetAddress = account.streetAddress
                viewModel.unit = account.unit
                viewModel.postalCode = account.postalCode
                if let latitude = account.latitude, let longitude = account.longitude {
                    viewModel.remember(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
                }
            } catch { model.error = error.localizedDescription }
        }
        .onChange(of: viewModel.coordinate?.latitude) { _, _ in
            if let coordinate = viewModel.coordinate { focusMap(on: coordinate) }
        }
        .onChange(of: viewModel.coordinate?.longitude) { _, _ in
            if let coordinate = viewModel.coordinate { focusMap(on: coordinate) }
        }
    }

    private var shedMap: some View {
        Map(position: $mapPosition) {
            if let coordinate = viewModel.coordinate {
                Marker("Your shed", coordinate: coordinate)
                    .tint(AppTheme.yellow)
            }
            UserAnnotation()
        }
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1)
        }
        .accessibilityLabel("Map of your saved location")
    }

    private func focusMap(on coordinate: CLLocationCoordinate2D) {
        withAnimation(.easeInOut(duration: 0.35)) {
            mapPosition = .region(
                MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }

    private func confirmLocation() async {
        let saved = await model.perform {
            let coordinate: CLLocationCoordinate2D
            if let found = viewModel.coordinate {
                coordinate = found
            } else {
                coordinate = try await PlaceService.coordinate(
                    for: "\(viewModel.streetAddress), \(viewModel.postalCode)"
                )
            }
            try await dependencies.communityRepository.saveAddress(
                street: viewModel.streetAddress,
                unit: viewModel.unit,
                postalCode: viewModel.postalCode,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            dependencies.savedShedCoordinate = coordinate
            if let account = try? await dependencies.accountRepository.loadAccount() {
                dependencies.offlineCache.saveAccount(account)
            }
        }
        if saved { router.go(to: .nearbyMap) }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.rounded(12, weight: .bold))
            .foregroundStyle(AppTheme.blue)
    }

    private func addressField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16))
            .padding(.horizontal, 15)
            .frame(height: 47)
            .background(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(AppTheme.border, lineWidth: 2)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
