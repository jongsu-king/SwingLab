import Foundation

public enum CourseAreaKind: String, Codable, CaseIterable, Sendable {
    case fairway, green, bunker, water, penalty, outOfBounds, tee, rough
    public var localizationKey: LocalizationKey {
        switch self {
        case .fairway: "Fairway"
        case .green: "Green"
        case .bunker: "Bunker"
        case .water: "Water"
        case .penalty: "Penalty area"
        case .outOfBounds: "Out of bounds"
        case .tee: "Tee"
        case .rough: "Rough"
        }
    }
    public var isHazard: Bool { [.bunker, .water, .penalty, .outOfBounds].contains(self) }
}

/// Coordinates retain their source. Importing OSM does not turn community mapping into a survey.
public struct CourseArea: Codable, Sendable, Identifiable, Equatable {
    public var id: String
    public var kind: CourseAreaKind
    public var vertices: [GeoCoordinate]
    public var holes: [[GeoCoordinate]]
    public var provenance: Provenance
    public var sourceURL: String?
    public init(id: String = UUID().uuidString, kind: CourseAreaKind, vertices: [GeoCoordinate],
                holes: [[GeoCoordinate]] = [], provenance: Provenance = .userEntered, sourceURL: String? = nil) {
        self.id = id; self.kind = kind; self.vertices = vertices; self.holes = holes
        self.provenance = provenance; self.sourceURL = sourceURL
    }
    public var isValid: Bool {
        guard let origin = vertices.first, origin.isValid else { return false }
        func projected(_ ring: [GeoCoordinate]) -> [PlanePoint] {
            ring.map { Geo.unproject($0, origin: origin, bearingDegrees: 0) }
        }
        let outer = projected(vertices), inner = holes.map(projected)
        guard Self.validRing(vertices, projected: outer), zip(holes, inner).allSatisfy({ Self.validRing($0.0, projected: $0.1) }) else { return false }
        for (index, ring) in inner.enumerated() {
            guard ring.allSatisfy({ Geometry.contains($0, polygon: outer) }), !Self.ringsCross(ring, outer) else { return false }
            for previous in inner.prefix(index) {
                guard !Self.ringsCross(ring, previous), !Geometry.contains(ring[0], polygon: previous),
                      !Geometry.contains(previous[0], polygon: ring) else { return false }
            }
        }
        return true
    }
    private static func crosses(_ a: PlanePoint, _ b: PlanePoint, _ c: PlanePoint, _ d: PlanePoint) -> Bool {
        func cross(_ p: PlanePoint, _ q: PlanePoint, _ r: PlanePoint) -> Double {
            (q.forward - p.forward) * (r.right - p.right) - (q.right - p.right) * (r.forward - p.forward)
        }
        return cross(a, b, c) * cross(a, b, d) < 0 && cross(c, d, a) * cross(c, d, b) < 0
    }
    private static func ringsCross(_ first: [PlanePoint], _ second: [PlanePoint]) -> Bool {
        for i in first.indices {
            for j in second.indices where crosses(first[i], first[(i + 1) % first.count], second[j], second[(j + 1) % second.count]) { return true }
        }
        return false
    }
    private static func validRing(_ coordinates: [GeoCoordinate], projected ring: [PlanePoint]) -> Bool {
        guard coordinates.count >= 3, coordinates.allSatisfy(\.isValid),
              Set(coordinates.map { "\($0.latitude),\($0.longitude)" }).count == coordinates.count else { return false }
        var twiceArea = 0.0
        for i in ring.indices {
            let next = (i + 1) % ring.count
            twiceArea += ring[i].forward * ring[next].right - ring[next].forward * ring[i].right
            for j in ring.indices where j > i + 1 && !(i == 0 && j == ring.count - 1) {
                if crosses(ring[i], ring[next], ring[j], ring[(j + 1) % ring.count]) { return false }
            }
        }
        return abs(twiceArea) > 0.02
    }
    public func probability(distribution: GaussianDispersion, origin: GeoCoordinate, bearingDegrees: Double,
                            sampleCount: Int = 2048) -> Double? {
        guard isValid, origin.isValid, bearingDegrees.isFinite else { return nil }
        let outer = vertices.map { Geo.unproject($0, origin: origin, bearingDegrees: bearingDegrees) }
        guard let mass = distribution.probability(in: outer, sampleCount: sampleCount) else { return nil }
        let excluded = holes.compactMap { ring in
            distribution.probability(in: ring.map { Geo.unproject($0, origin: origin, bearingDegrees: bearingDegrees) }, sampleCount: sampleCount)
        }.reduce(0, +)
        return max(0, min(1, mass - excluded))
    }
}

extension Geo {
    /// Exact inverse of the spherical distance/bearing projection, in metres.
    public static func unproject(_ point: GeoCoordinate, origin: GeoCoordinate, bearingDegrees: Double) -> PlanePoint {
        let radius = distance(from: origin, to: point)
        let angle = (bearing(from: origin, to: point) - bearingDegrees) * .pi / 180
        return .init(forward: radius * cos(angle), right: radius * sin(angle))
    }
}

public struct OSMHoleLine: Sendable, Equatable {
    public let id: String
    public let number: Int?
    public let par: Int?
    public let coordinates: [GeoCoordinate]
}
public struct OSMCourseGeometry: Sendable {
    public let areas: [CourseArea]
    public let holes: [OSMHoleLine]
    public let skippedElements: Int
}

/// Reads Overpass `out geom` closed ways, complete multipolygon rings, and hole lines.
/// Incomplete geometry and open area ways are rejected; they are never silently closed.
public enum OSMCourseParser {
    private struct Document: Decodable { let elements: [Element] }
    private struct Coordinate: Decodable { let lat: Double; let lon: Double; var value: GeoCoordinate { .init(latitude: lat, longitude: lon) } }
    private struct Member: Decodable { let role: String?; let geometry: [Coordinate]? }
    private struct Element: Decodable {
        let type: String; let id: Int64; let tags: [String: String]?
        let geometry: [Coordinate]?; let members: [Member]?
    }
    public static func parse(_ data: Data) throws -> OSMCourseGeometry {
        let document = try JSONDecoder().decode(Document.self, from: data)
        var areas: [CourseArea] = [], holes: [OSMHoleLine] = [], skipped = 0
        func ring(_ coordinates: [Coordinate]?) -> [GeoCoordinate]? {
            guard let points = coordinates?.map(\.value), points.count >= 4,
                  points.first == points.last, points.allSatisfy(\.isValid) else { return nil }
            return Array(points.dropLast())
        }
        for element in document.elements {
            let tags = element.tags ?? [:], id = "osm:\(element.type):\(element.id)"
            if tags["golf"] == "hole", let coordinates = element.geometry?.map(\.value),
               coordinates.count >= 2, coordinates.allSatisfy(\.isValid) {
                holes.append(.init(id: id, number: tags["ref"].flatMap(Int.init), par: tags["par"].flatMap(Int.init), coordinates: coordinates))
                continue
            }
            let kind: CourseAreaKind?
            switch tags["golf"] {
            case "fairway": kind = .fairway
            case "green": kind = .green
            case "bunker": kind = .bunker
            case "tee": kind = .tee
            case "rough": kind = .rough
            case "water_hazard", "lateral_water_hazard": kind = .water
            default: kind = tags["natural"] == "water" ? .water : nil
            }
            guard let kind else { skipped += 1; continue }
            let source = "https://www.openstreetmap.org/\(element.type)/\(element.id)"
            if element.type == "way", let vertices = ring(element.geometry) {
                let area = CourseArea(id: id, kind: kind, vertices: vertices, provenance: .estimated, sourceURL: source)
                if area.isValid { areas.append(area) } else { skipped += 1 }
            } else if element.type == "relation", let members = element.members {
                let outers = members.filter { $0.role == "outer" }.compactMap { ring($0.geometry) }
                let inners = members.filter { $0.role == "inner" }.compactMap { ring($0.geometry) }
                // Fragmented relation members require ring assembly, deliberately rejected here.
                guard outers.count == 1, outers.count + inners.count == members.count else { skipped += 1; continue }
                let area = CourseArea(id: id, kind: kind, vertices: outers[0], holes: inners, provenance: .estimated, sourceURL: source)
                if area.isValid { areas.append(area) } else { skipped += 1 }
            } else { skipped += 1 }
        }
        return .init(areas: areas, holes: holes, skippedElements: skipped)
    }
}
