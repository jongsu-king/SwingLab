import CoreLocation
import Foundation
import Observation
import SwingLabCore

struct CourseLocationFix: Sendable {
    let latitude: Double
    let longitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
    var coordinate: GeoCoordinate { GeoCoordinate(latitude: latitude, longitude: longitude) }
    var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }

    func isUsableForShot(at date: Date = .now) -> Bool {
        let age = date.timeIntervalSince(timestamp)
        return latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude)
            && (-180...180).contains(longitude) && horizontalAccuracy >= 0
            && horizontalAccuracy <= 30 && age >= -5 && age <= 20
    }
}

@MainActor @Observable
final class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var fix: CourseLocationFix?
    var authorization: CLAuthorizationStatus = .notDetermined
    var isRequesting = false
    /// Localization keys; never presents raw platform errors to the user.
    var errorKey: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorization = manager.authorizationStatus
    }

    func requestFix() {
        errorKey = nil
        guard CLLocationManager.locationServicesEnabled() else {
            errorKey = "Location services are unavailable. You can still choose targets on the map."
            return
        }
        switch manager.authorizationStatus {
        case .notDetermined:
            isRequesting = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isRequesting = true
            manager.requestLocation()
        case .restricted, .denied:
            isRequesting = false
            errorKey = "Location access is off. Enable it in iPhone Settings to record GPS shots."
        @unknown default:
            isRequesting = false
            errorKey = "Location services are unavailable. You can still choose targets on the map."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isRequesting {
            switch authorization {
            case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
            case .restricted, .denied:
                isRequesting = false
                errorKey = "Location access is off. Enable it in iPhone Settings to record GPS shots."
            default: break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isRequesting = false
        guard let newest = locations.filter({ $0.horizontalAccuracy >= 0 }).max(by: { $0.timestamp < $1.timestamp }) else {
            errorKey = "No usable GPS fix. Move to an open area and try again."
            return
        }
        fix = CourseLocationFix(latitude: newest.coordinate.latitude, longitude: newest.coordinate.longitude,
                                horizontalAccuracy: newest.horizontalAccuracy, timestamp: newest.timestamp)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isRequesting = false
        errorKey = "No usable GPS fix. Move to an open area and try again."
    }
}
