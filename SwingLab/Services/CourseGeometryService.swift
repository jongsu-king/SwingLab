import Foundation
import SwingLabCore

/// Explicit user action only. The saved CourseHole envelope is the offline cache.
actor CourseGeometryService {
    static let weatherKitEnabled = false
    func fetch(near coordinate: GeoCoordinate) async throws -> OSMCourseGeometry {
        guard coordinate.isValid else { throw ModelError.invalidInput }
        let around = "around:1200,\(coordinate.latitude),\(coordinate.longitude)"
        let query = "[out:json][timeout:20];(way[\"golf\"~\"^(fairway|green|bunker|tee|hole|water_hazard|lateral_water_hazard|rough)$\"](\(around));way[\"natural\"=\"water\"](\(around)););out geom;"
        var components = URLComponents(string: "https://overpass-api.de/api/interpreter")!
        components.queryItems = [.init(name: "data", value: query)]
        guard let url = components.url else { throw ModelError.invalidInput }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 10_000_000 else { throw ModelError.invalidInput }
        return try OSMCourseParser.parse(data)
    }
}
