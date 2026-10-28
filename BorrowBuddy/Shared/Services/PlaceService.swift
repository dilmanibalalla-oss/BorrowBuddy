import _LocationEssentials
import CoreLocation
import Combine
import Foundation

enum PlaceService {
    static func coordinate(for address: String) async throws -> CLLocationCoordinate2D {
        let results = try await CLGeocoder().geocodeAddressString(address)
        guard let coordinate = results.first?.location?.coordinate else {
            throw CommunityError.invalidInput("That address could not be located. Include the city and country.")
        }
        return coordinate
    }
}

@MainActor
final class ArrivalLocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var error: String?
    @Published private(set) var isLoading = false
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func refresh() {
        error = nil
        isLoading = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: isLoading = false; error = "Allow location in Settings to confirm arrival."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isLoading, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        isLoading = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
        isLoading = false
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> Double? {
        location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func verifiedAccuracy(at coordinate: CLLocationCoordinate2D) throws -> Double {
        guard let location, let distance = distance(to: coordinate),
              LoanRules.canVerifyArrival(distance: distance, accuracy: location.horizontalAccuracy,
                                        age: Date().timeIntervalSince(location.timestamp)) else {
            throw CommunityError.expiredLocation
        }
        return location.horizontalAccuracy
    }
}
