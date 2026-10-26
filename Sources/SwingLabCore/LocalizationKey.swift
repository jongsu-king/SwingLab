import Foundation

/// Localization inputs are source literals or typed enum mappings, never runtime/user data.
/// StaticString deliberately excludes interpolation and String-to-key conversion.
public struct LocalizationKey: ExpressibleByStringLiteral, Hashable, Sendable, Encodable {
    public let rawValue: String
    public init(stringLiteral value: StaticString) { rawValue = value.description }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
