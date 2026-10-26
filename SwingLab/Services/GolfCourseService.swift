import Foundation
@preconcurrency import MapKit

struct CourseSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
}

@MainActor
protocol GolfCourseRepository {
    func search(query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [CourseSearchResult]
}

/// MapKit supplies places and map tiles. Detailed hole geometry is deliberately absent.
@MainActor
struct MapKitGolfCourseRepository: GolfCourseRepository {
    func search(query: String, near coordinate: CLLocationCoordinate2D?) async throws -> [CourseSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course " + query.trimmingCharacters(in: .whitespacesAndNewlines)
        request.resultTypes = .pointOfInterest
        if let coordinate {
            request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        let response = try await MKLocalSearch(request: request).start()
        try Task.checkCancellation()
        return response.mapItems.map {
            CourseSearchResult(name: $0.name ?? query, subtitle: $0.placemark.title ?? "", coordinate: $0.placemark.coordinate)
        }
    }
}
