//
//  LocationManager.swift
//  BorrowBuddy
//

import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI
import _LocationEssentials

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var street = ""
    @Published var unit = ""
    @Published var postalCode = ""
    @Published var isLocating = false
    @Published var isGeocoding = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var didReceiveFix = false
    private var locationTimeoutTask: Task<Void, Never>?
    private var geocodeRequestID = UUID()

    var hasResolvedCoordinate: Bool { coordinate != nil }

    var canConfirm: Bool {
        !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !postalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && coordinate != nil
            && !isLocating
            && !isGeocoding
    }

    var shedLocation: ShedLocation? {
        guard let coordinate else { return nil }
        return ShedLocation(
            street: street.trimmingCharacters(in: .whitespacesAndNewlines),
            unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
            postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func requestPermissionAndLocate() {
        guard !isLocating else { return }
        errorMessage = nil
        didReceiveFix = false
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            scheduleLocationTimeout()
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdating()
        case .denied, .restricted:
            isLocating = false
            errorMessage = "Location is off. Enable it in Settings → BorrowBuddy → Location, or type your address. On Simulator: Features → Location → Custom Location."
        @unknown default:
            errorMessage = "Unable to access location right now."
        }
    }

    func updatePin(to newCoordinate: CLLocationCoordinate2D) {
        stopUpdating()
        errorMessage = nil
        coordinate = newCoordinate
        cameraPosition = .region(
            MKCoordinateRegion(
                center: newCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
        Task { await reverseGeocode(newCoordinate) }
    }

    func geocodeTypedAddress() async {
        let query = [street, unit, postalCode]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        guard !query.isEmpty else {
            errorMessage = "Enter a street address and postal code first."
            return
        }

        let requestID = beginGeocoding()
        let timeout = geocodeTimeout()
        errorMessage = nil
        defer {
            timeout.cancel()
            if geocodeRequestID == requestID { isGeocoding = false }
        }

        do {
            let placemarks = try await Self.forwardGeocode(query, using: geocoder)
            guard geocodeRequestID == requestID else { return }
            guard let location = placemarks.first?.location else {
                errorMessage = "Couldn't find that address. Try adjusting it."
                return
            }
            apply(placemark: placemarks.first, coordinate: location.coordinate)
        } catch {
            guard geocodeRequestID == requestID else { return }
            errorMessage = "Couldn't look up that address in time. Check your connection, try again, or choose a pin on the map."
        }
    }

    private func startUpdating() {
        isLocating = true
        errorMessage = nil
        didReceiveFix = false
        scheduleLocationTimeout()
        manager.startUpdatingLocation()
    }

    private func scheduleLocationTimeout() {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }
            guard let self, self.isLocating else { return }
            self.stopUpdating()
            self.errorMessage = "Location took too long. Tap the map to place your pin, type your address, or try again."
        }
    }

    private func stopUpdating() {
        locationTimeoutTask?.cancel()
        locationTimeoutTask = nil
        manager.stopUpdatingLocation()
        isLocating = false
    }

    // Cancel the previous lookup and ignore its eventual result.
    private func beginGeocoding() -> UUID {
        geocodeRequestID = UUID()
        geocoder.cancelGeocode()
        isGeocoding = true
        return geocodeRequestID
    }

    private func geocodeTimeout() -> Task<Void, Never> {
        let requestID = geocodeRequestID
        return Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
            guard let self, self.geocodeRequestID == requestID else { return }
            self.geocoder.cancelGeocode()
        }
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async {
        let requestID = beginGeocoding()
        let timeout = geocodeTimeout()
        defer {
            timeout.cancel()
            if geocodeRequestID == requestID { isGeocoding = false }
        }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await Self.reverseGeocode(location, using: geocoder)
            guard geocodeRequestID == requestID else { return }
            apply(placemark: placemarks.first, coordinate: coordinate, preserveTypedFields: false)
        } catch {
            guard geocodeRequestID == requestID else { return }
            errorMessage = "Your pin is saved, but the address lookup failed or timed out. You can enter the address manually."
        }
    }

    private static func forwardGeocode(_ query: String, using geocoder: CLGeocoder) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.geocodeAddressString(query) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    private static func reverseGeocode(_ location: CLLocation, using geocoder: CLGeocoder) async throws -> [CLPlacemark] {
        try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: placemarks ?? [])
                }
            }
        }
    }

    private func apply(
        placemark: CLPlacemark?,
        coordinate: CLLocationCoordinate2D,
        preserveTypedFields: Bool = false
    ) {
        self.coordinate = coordinate
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )

        guard let placemark, !preserveTypedFields else { return }

        let number = placemark.subThoroughfare ?? ""
        let thoroughfare = placemark.thoroughfare ?? ""
        let composed = [number, thoroughfare]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !composed.isEmpty {
            street = composed
        } else if let name = placemark.name {
            street = name
        }
        if let postal = placemark.postalCode, !postal.isEmpty {
            postalCode = postal
        }
        if let sub = placemark.subLocality, unit.isEmpty {
            unit = sub
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                if isLocating { startUpdating() }
            case .denied, .restricted:
                stopUpdating()
                errorMessage = "Location is off. Enable it in Settings, or type your address. On Simulator: Features → Location → Custom Location."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            guard isLocating, !didReceiveFix, location.horizontalAccuracy >= 0 else { return }
            didReceiveFix = true
            stopUpdating()
            updatePin(to: location.coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard isLocating else { return }
            stopUpdating()
            let nsError = error as NSError
            if nsError.domain == kCLErrorDomain, nsError.code == CLError.denied.rawValue {
                errorMessage = "Location permission denied. Enable it in Settings, or type your address."
            } else {
                errorMessage = "Couldn't get GPS. On Simulator use Features → Location → Apple / Custom Location, or type the address."
            }
        }
    }
}

