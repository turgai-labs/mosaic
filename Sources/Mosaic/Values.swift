public import Foundation

// Each value a piece holds is made only when it's right, here or decoded: a widget that exists is
// one that can be shown.

/// A piece's name: trimmed, never blank, its own among its siblings.
public struct PieceID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ text: String) throws(WidgetProblem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .noID }
        rawValue = trimmed
    }

    public init(from decoder: any Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// Words that say something: trimmed, never empty. A text's words, a label, a description.
public struct Words: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ text: String) throws(WidgetProblem) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .noWords }
        rawValue = trimmed
    }

    public init(from decoder: any Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// How far apart pieces are, in points: finite, from 0.
public struct Points: Hashable, Codable, Sendable {
    public let rawValue: Double

    /// Twelve points, the spacing pieces have unless they say.
    public static let standard = Points(checked: 12)

    public init(_ value: Double) throws(WidgetProblem) {
        guard value >= 0, value.isFinite else { throw .negativeSpacing(value) }
        rawValue = value
    }

    private init(checked value: Double) { rawValue = value }

    public init(from decoder: any Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(Double.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// How wide a picture is, in points: finite, more than 0.
public struct Width: Hashable, Codable, Sendable {
    public let rawValue: Double

    public init(_ value: Double) throws(WidgetProblem) {
        guard value > 0, value.isFinite else { throw .noWidth(value) }
        rawValue = value
    }

    public init(from decoder: any Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(Double.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// An address on the web: http or https, with a host.
public struct WebAddress: Hashable, Codable, Sendable, CustomStringConvertible {
    public let url: URL

    public init(_ text: String) throws(WidgetProblem) {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else { throw .notAWebAddress(address) }
        self.url = url
    }

    public init(from decoder: any Decoder) throws {
        try self.init(try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(url.absoluteString)
    }

    public var description: String { url.absoluteString }
}

/// Why a widget can't be made.
public enum WidgetProblem: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    case noID
    case noWords
    case noText
    case noLabel
    case noDescription
    case sameID(String)
    case negativeSpacing(Double)
    case notAWebAddress(String)
    case noWidth(Double)

    public var description: String {
        switch self {
        case .noID: "An id is empty: give it one."
        case .noWords: "Words are empty: they say something."
        case .noText: "A text has no words: give it `words`."
        case .noLabel: "A button or a toggle has no label: give it `label`."
        case .noDescription: "A picture has no description: say what it shows, in `description`."
        case .sameID(let id): "Two things side by side have the id `\(id)`: each id is one thing's among its siblings."
        case .negativeSpacing(let spacing): "A spacing is \(spacing): it's points apart, from 0."
        case .notAWebAddress(let url): "`\(url)` isn't a web address: a picture's url starts with https:// or http://."
        case .noWidth(let width): "A picture's width is \(width): it's points wide, more than 0, or leave `width` out."
        }
    }
}

extension Words {
    /// `text` as words, or else `problem`: what's empty, said for the piece it's in.
    static func of(_ text: String, or problem: WidgetProblem) throws(WidgetProblem) -> Words {
        do { return try Words(text) } catch { throw problem }
    }
}
