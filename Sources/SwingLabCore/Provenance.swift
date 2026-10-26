import Foundation

/// Stable storage IDs. Labels are localization keys, never persistence values.
public enum Provenance: String, Codable, CaseIterable, Sendable {
    case measured, visionDerived, audioDerived, estimated, simulated, userEntered, unavailable

    /// Audio timing is sensor-derived and belongs to the Measured category.
    public var category: Provenance { self == .audioDerived ? .measured : self }
    public var localizationKey: LocalizationKey {
        switch self {
        case .measured: "Measured"
        case .visionDerived: "Vision-derived"
        case .audioDerived: "Audio-derived"
        case .estimated: "Estimated"
        case .simulated: "Simulated"
        case .userEntered: "User-entered"
        case .unavailable: "Unavailable"
        }
    }

    /// Unknown legacy values must not become evidence for a measurement.
    public init(legacyValue: String) {
        if let value = Self(rawValue: legacyValue) { self = value; return }
        switch legacyValue {
        case "Measured": self = .measured
        case "Vision-derived", "Vision-Derived": self = .visionDerived
        case "Audio-derived", "Audio-Derived": self = .audioDerived
        case "Estimated": self = .estimated
        case "Simulated": self = .simulated
        case "User-entered", "User-Entered": self = .userEntered
        default: self = .unavailable
        }
    }
    public init(from decoder: Decoder) throws {
        self.init(legacyValue: try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A number cannot be displayed without describing its origin and method.
/// Values are stored in SI units; dimensionless quantities use "1". Units such
/// as yards, percent, and fps are presentation concerns, not stored conversions.
public struct ProvenancedValue: Codable, Equatable, Sendable {
    public let value: Double?
    public let unit: String
    public let provenance: Provenance
    public let confidence: Double?
    public let method: String
    public let sampleCount: Int?

    /// Invalid metadata is never repaired by inventing confidence or samples.
    /// A missing/non-finite value, missing unit/method, or unavailable origin
    /// produces an unavailable value. Out-of-range confidence/count is omitted.
    public init(value: Double?, unit: String, provenance: Provenance,
                confidence: Double? = nil, method: String, sampleCount: Int? = nil) {
        let validUnit = !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let validMethod = !method.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let validValue = value.flatMap { $0.isFinite ? $0 : nil }
        let available = validValue != nil && validUnit && validMethod && provenance != .unavailable
        self.value = available ? validValue : nil
        self.unit = unit
        self.provenance = available ? provenance : .unavailable
        self.confidence = available ? confidence.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil } : nil
        self.method = validMethod ? method : "unavailable.unspecifiedMethod"
        self.sampleCount = sampleCount.flatMap { $0 >= 0 ? $0 : nil }
    }

    private enum CodingKeys: String, CodingKey { case value, unit, provenance, confidence, method, sampleCount }
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        self.init(value: try fields.decodeIfPresent(Double.self, forKey: .value),
                  unit: try fields.decode(String.self, forKey: .unit),
                  provenance: try fields.decodeIfPresent(Provenance.self, forKey: .provenance) ?? .unavailable,
                  confidence: try fields.decodeIfPresent(Double.self, forKey: .confidence),
                  method: try fields.decode(String.self, forKey: .method),
                  sampleCount: try fields.decodeIfPresent(Int.self, forKey: .sampleCount))
    }
}

public enum RecordingSource: String, CaseIterable, Codable, Sendable, Identifiable {
    case recorded, imported, unspecified
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .recorded: "Recorded"
        case .imported: "Imported"
        case .unspecified: "Unspecified"
        }
    }
    public init(legacyValue: String) {
        if let value = Self(rawValue: legacyValue) { self = value; return }
        switch legacyValue {
        case "Recorded": self = .recorded
        case "Imported": self = .imported
        default: self = .unspecified
        }
    }
    public init(from decoder: Decoder) throws {
        self.init(legacyValue: try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum CameraAngle: String, CaseIterable, Codable, Sendable, Identifiable {
    case faceOn, downTheLine, unspecified
    public var id: String { rawValue }
    public var localizationKey: LocalizationKey {
        switch self {
        case .faceOn: "Face-on"
        case .downTheLine: "Down the line"
        case .unspecified: "Unspecified"
        }
    }
    public init(legacyValue: String) {
        if let value = Self(rawValue: legacyValue) { self = value; return }
        switch legacyValue {
        case "Face-on": self = .faceOn
        case "Down the line", "Down-the-line": self = .downTheLine
        default: self = .unspecified
        }
    }
    public init(from decoder: Decoder) throws {
        self.init(legacyValue: try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
