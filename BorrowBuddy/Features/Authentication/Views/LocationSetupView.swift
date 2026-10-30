//
//  LocationSetupView.swift
//  BorrowBuddy
//

import MapKit
import SwiftUI

struct LocationSetupView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var locationManager = LocationManager()

    @State private var showMap = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var canAttemptConfirm: Bool {
        let hasAddress = !locationManager.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !locationManager.postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasAddress || locationManager.hasResolvedCoordinate)
            && !isSaving
            && !locationManager.isLocating
            && !locationManager.isGeocoding
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Find Your Shed")
                        .font(AppTheme.rounded(28, weight: .heavy))
                        .foregroundStyle(AppTheme.blue)
                        .padding(.top, 24)
                        .accessibilityAddTraits(.isHeader)

                    Text("Set your tool shed's location so neighbors can discover your shared tools. Use your current location, or type your address below.")
                        .font(AppTheme.system(16))
                        .foregroundStyle(AppTheme.blue.opacity(0.85))
                        .lineSpacing(3)
                        .padding(.top, 10)

                    PrimaryButton(
                        title: locationManager.isLocating ? "Finding you..." : "Use My Location",
                        systemImage: "location.fill",
                        enabled: !locationManager.isLocating && !isSaving,
                        accessibilityHint: "Fills the address from your current location."
                    ) {
                        showMap = true
                        locationManager.requestPermissionAndLocate()
                    }
                    .padding(.top, 28)

                    shedMap
                        .padding(.top, 16)

                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                        Text("OR")
                            .font(AppTheme.rounded(13, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryText)
                        Rectangle()
                            .fill(AppTheme.border)
                            .frame(height: 1)
                    }
                    .padding(.vertical, 22)

                    AuthTextField(
                        title: "Street Address",
                        placeholder: "742 Evergreen Terrace",
                        text: $locationManager.street,
                        kind: .street
                    )

                    HStack(alignment: .top, spacing: 12) {
                        AuthTextField(
                            title: "Unit / Apt",
                            placeholder: "Optional",
                            text: $locationManager.unit,
                            kind: .unit
                        )

                        AuthTextField(
                            title: "Postal Code",
                            placeholder: "90210",
                            text: $locationManager.postalCode,
                            kind: .postal
                        )
                    }
                    .padding(.top, 14)

                    if locationManager.hasResolvedCoordinate {
                        Label("Location pinned on the map", systemImage: "mappin.and.ellipse")
                            .font(AppTheme.system(13, weight: .semibold))
                            .foregroundStyle(AppTheme.green)
                            .padding(.top, 14)
                            .accessibilityLabel("Location pinned on the map")
                    }

                    if let message = errorMessage ?? locationManager.errorMessage {
                        DismissingErrorText(message: message, topPadding: 14)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)

            PrimaryButton(
                title: confirmTitle,
                enabled: canAttemptConfirm,
                accessibilityHint: "Saves this address and opens the map."
            ) {
                Task { await confirmLocation() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .background(AppTheme.background)
        .accessibilityAnnounce(errorMessage ?? locationManager.errorMessage)
        .onAppear {
            if locationManager.coordinate == nil {
                locationManager.requestPermissionAndLocate()
            }
        }
        .sheet(isPresented: $showMap) {
            LocationMapSheet(locationManager: locationManager)
        }
    }

    private var shedMap: some View {
        Map(position: $locationManager.cameraPosition) {
            if let coordinate = locationManager.coordinate {
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
        .accessibilityLabel("Map of your location")
    }

    private var confirmTitle: String {
        if isSaving { return "Saving..." }
        if locationManager.isGeocoding { return "Looking up..." }
        return "Confirm Location"
    }

    private func confirmLocation() async {
        isSaving = true
        errorMessage = nil

        if locationManager.coordinate == nil {
            await locationManager.geocodeTypedAddress()
        }

        guard let shed = locationManager.shedLocation else {
            errorMessage = locationManager.errorMessage
                ?? "Set a location with the map or a valid address first."
            isSaving = false
            return
        }

        do {
            try await dependencies.userProfileService.saveShedLocation(shed)
            let pin = CLLocationCoordinate2D(latitude: shed.latitude, longitude: shed.longitude)
            dependencies.savedShedCoordinate = pin
            if let saved = try? await dependencies.accountRepository.loadAccount() {
                dependencies.offlineCache.saveAccount(saved)
            }
            try await dependencies.authenticationService.completeOnboarding()
            router.go(to: .nearbyMap)
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }
}

private struct LocationMapSheet: View {
    @ObservedObject var locationManager: LocationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MapReader { proxy in
                    Map(position: $locationManager.cameraPosition) {
                        if let coordinate = locationManager.coordinate {
                            Marker("Your shed", coordinate: coordinate)
                                .tint(AppTheme.yellow)
                        }
                        UserAnnotation()
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                    }
                    .onTapGesture { position in
                        if let coordinate = proxy.convert(position, from: .local) {
                            locationManager.updatePin(to: coordinate)
                        }
                    }
                }
                .overlay(alignment: .center) {
                    if locationManager.isLocating && locationManager.coordinate == nil {
                        ProgressView("Finding your location…")
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(locationManager.street.isEmpty ? "Locating your shed…" : locationManager.street)
                        .font(AppTheme.rounded(16, weight: .semibold))
                        .foregroundStyle(AppTheme.blue)

                    if !locationManager.postalCode.isEmpty {
                        Text(locationManager.postalCode)
                            .font(AppTheme.system(14))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    if let errorMessage = locationManager.errorMessage {
                        DismissingErrorText(message: errorMessage)
                    }

                    Text("Tap the map to move the pin.")
                        .font(AppTheme.system(12))
                        .foregroundStyle(AppTheme.secondaryText)

                    PrimaryButton(
                        title: "Use This Location",
                        systemImage: "mappin.circle.fill",
                        enabled: locationManager.coordinate != nil
                    ) {
                        dismiss()
                    }
                }
                .padding(20)
                .background(AppTheme.background)
            }
            .navigationTitle("Your Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        locationManager.requestPermissionAndLocate()
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(AppTheme.blue)
                    }
                    .accessibilityLabel("Refresh my location")
                }
            }
            .background(AppTheme.background)
        }
        .presentationDetents([.large])
        .onAppear {
            if locationManager.coordinate == nil {
                locationManager.requestPermissionAndLocate()
            } else {
                focusOnPin()
            }
        }
        .onChange(of: locationManager.coordinate?.latitude) { _, _ in
            focusOnPin()
        }
        .onChange(of: locationManager.coordinate?.longitude) { _, _ in
            focusOnPin()
        }
    }

    private func focusOnPin() {
        guard let coordinate = locationManager.coordinate else { return }
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        withAnimation(.easeInOut(duration: 0.35)) {
            locationManager.cameraPosition = .region(region)
        }
    }
}
