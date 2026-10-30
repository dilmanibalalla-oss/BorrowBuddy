import CoreLocation
import Combine
import _LocationEssentials

final class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var streetAddress = ""
    @Published var unit = ""
    @Published var postalCode = ""
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var locationStatus = ""
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var canContinue: Bool {
        !streetAddress.trimmingCharacters(in: .whitespaces).isEmpty &&
        !postalCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func useCurrentLocation() {
        locationStatus = "Finding your location..."
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        coordinate = location.coordinate
        locationStatus = String(format: "Location found: %.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] places, _ in
            guard let place = places?.first else { return }
            DispatchQueue.main.async {
                self?.streetAddress = [place.subThoroughfare, place.thoroughfare, place.locality, place.country].compactMap { $0 }.joined(separator: ", ")
                self?.postalCode = place.postalCode ?? ""
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationStatus = "Enter your address manually to continue."
    }
}

