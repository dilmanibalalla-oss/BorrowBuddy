import CoreLocation
import Foundation

extension Notification.Name {
    static let dropOffRegionEntered = Notification.Name("borrowbuddy.dropOffRegionEntered")
}

/// Watches a 50 m CLCircularRegion around each active drop-off.
/// Entry asks the app to start the existing return check. It does not settle the loan.
final class DropOffGeofenceMonitor: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waitingForLocationID: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func sync(loans: [ReservationRecord], borrowerID: String?) {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
        guard status == .authorizedAlways || status == .authorizedWhenInUse else { return }

        let regions = loans.compactMap { loan -> CLCircularRegion? in
            guard DropOffRegionPolicy.shouldMonitor(loan, borrowerID: borrowerID) else { return nil }
            return DropOffRegionPolicy.region(for: loan)
        }
        let identifiers = Set(regions.map(\.identifier))
        for region in manager.monitoredRegions {
            if !identifiers.contains(region.identifier) {
                manager.stopMonitoring(for: region)
            }
        }
        for region in regions where !manager.monitoredRegions.contains(where: { $0.identifier == region.identifier }) {
            manager.startMonitoring(for: region)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        waitingForLocationID = region.identifier
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let identifier = waitingForLocationID, let location = locations.last else { return }
        waitingForLocationID = nil
        NotificationCenter.default.post(
            name: .dropOffRegionEntered,
            object: nil,
            userInfo: [
                "reservationID": identifier,
                "location": location
            ]
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let identifier = waitingForLocationID else { return }
        waitingForLocationID = nil
        NotificationCenter.default.post(
            name: .dropOffRegionEntered,
            object: nil,
            userInfo: ["reservationID": identifier]
        )
    }
}
