import Foundation

public struct SwingTiming: Codable, Equatable, Sendable {
    public let backswing: Double
    public let downswing: Double
    public var tempo: Double { backswing / downswing }
    public var total: Double { backswing + downswing }
    public init(address: Double, top: Double, impact: Double) throws {
        guard [address, top, impact].allSatisfy(\.isFinite), address >= 0, top > address, impact > top else { throw ModelError.invalidInput }
        backswing = top - address; downswing = impact - top
    }
}

public enum LanguageResolver {
    public static let supported = ["en", "ko", "ja", "zh-Hans", "zh-Hant", "es", "pt-BR", "de", "fr", "it", "th", "vi"]
    public static func resolve(selection: String, preferred: [String]) -> String {
        if selection != "system" { return match(selection) ?? "en" }
        return preferred.lazy.compactMap(match).first ?? "en"
    }
    private static func match(_ code: String) -> String? {
        let code = code.replacingOccurrences(of: "_", with: "-")
        if supported.contains(code) { return code }
        if code.hasPrefix("zh") {
            return code.contains("Hant") || code.contains("TW") || code.contains("HK") || code.contains("MO") ? "zh-Hant" : "zh-Hans"
        }
        if code.hasPrefix("pt") { return "pt-BR" }
        let base = String(code.split(separator: "-").first ?? "")
        return supported.contains(base) ? base : nil
    }
}
