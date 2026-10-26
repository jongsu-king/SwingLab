import Foundation
import MapKit
import SwingLabCore

struct CourseLandingEstimate {
    let expectedCoordinate: CLLocationCoordinate2D
    let carryMeters: Double
    let lateralMeters: Double
    let remainingMeters: Double
    let region50: [CLLocationCoordinate2D]
    let region80: [CLLocationCoordinate2D]

    @MainActor
    init?(origin: GeoCoordinate, target: GeoCoordinate, club: GolfClub) {
        guard let carry = club.carryMeters, carry.isFinite, carry > 0,
              club.lateralMeanMeters.isFinite,
              Geo.distance(from: origin, to: target) > 0.1 else { return nil }
        let bearing = Geo.bearing(from: origin, to: target)
        let expected = Geo.project(origin: origin, bearingDegrees: bearing,
                                   forward: carry, right: club.lateralMeanMeters)
        expectedCoordinate = CLLocationCoordinate2D(latitude: expected.latitude, longitude: expected.longitude)
        carryMeters = carry
        lateralMeters = club.lateralMeanMeters
        remainingMeters = Geo.distance(from: expected, to: target)
        if let carrySD = club.carryStdDevMeters, let lateralSD = club.lateralStdDevMeters,
           let distribution = try? GaussianDispersion(meanCarry: carry, meanLateral: club.lateralMeanMeters,
                                                     carrySD: carrySD, lateralSD: lateralSD,
                                                     correlation: club.dispersionCorrelation) {
            func coordinates(probability: Double) -> [CLLocationCoordinate2D] {
                distribution.ellipse(probability: probability, segments: 72).map { point in
                    let coordinate = Geo.project(origin: origin, bearingDegrees: bearing, forward: point.forward, right: point.right)
                    return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
                }
            }
            region50 = coordinates(probability: 0.5)
            region80 = coordinates(probability: 0.8)
        } else {
            region50 = []
            region80 = []
        }
    }
}
