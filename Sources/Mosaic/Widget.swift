public import Foundation

/// A widget: pieces one under another or side by side, words, buttons and pictures, nested as deep
/// as it needs. Each piece's `id`, when it's given, is what it is from one widget to the next, as
/// SwiftUI's `id` is; without one, a button is its label, and anything else its place.
public indirect enum Widget: Equatable, Sendable {
    /// Pieces side by side, left to right, aligned, `spacing` points apart.
    case row(id: String? = nil, [Widget], alignment: RowAlignment = .center, spacing: Double = 12)
    /// Pieces one under another, top to bottom, aligned, `spacing` points apart.
    case column(id: String? = nil, [Widget], alignment: ColumnAlignment = .center, spacing: Double = 12)
    /// Words to read, in a style and colour.
    case text(id: String? = nil, words: String, style: TextStyle = .body, color: TextColor = .primary)
    /// A button, known by its label.
    case button(id: String? = nil, label: String, kind: ButtonKind = .normal)
    /// A picture from the web, `description` saying what it shows, `width` points wide, or as wide
    /// as there's room for.
    case image(
        id: String? = nil, url: URL, description: String, aspectRatio: AspectRatio = .original, fit: ImageFit = .fit,
        width: Double? = nil)
}

extension Widget {
    /// The widget as it's shown: every text and label there and trimmed, every picture from the
    /// web, saying what it shows, every spacing and width a real one, and every button's label and
    /// every id its own.
    public func checked() throws(WidgetProblem) -> Widget {
        let widget = try trimmed()
        var labels: Set<String> = []
        for label in widget.buttons where !labels.insert(label).inserted {
            throw .sameLabel(label)
        }
        var ids: Set<String> = []
        for id in widget.ids where !ids.insert(id).inserted {
            throw .sameID(id)
        }
        return widget
    }

    private func trimmed() throws(WidgetProblem) -> Widget {
        switch self {
        case .row(let id, let items, let alignment, let spacing):
            var trimmed: [Widget] = []
            for item in items { trimmed.append(try item.trimmed()) }
            return .row(
                id: try Self.identified(id), trimmed, alignment: alignment, spacing: try Self.spaced(spacing))
        case .column(let id, let items, let alignment, let spacing):
            var trimmed: [Widget] = []
            for item in items { trimmed.append(try item.trimmed()) }
            return .column(
                id: try Self.identified(id), trimmed, alignment: alignment, spacing: try Self.spaced(spacing))
        case .text(let id, let words, let style, let color):
            let words = words.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { throw .noText }
            return .text(id: try Self.identified(id), words: words, style: style, color: color)
        case .button(let id, let label, let kind):
            let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw .noLabel }
            return .button(id: try Self.identified(id), label: label, kind: kind)
        case .image(let id, let url, let description, let aspectRatio, let fit, let width):
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else {
                throw .notAWebAddress(url.absoluteString)
            }
            let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { throw .noDescription }
            if let width { guard width > 0, width.isFinite else { throw .noWidth(width) } }
            return .image(
                id: try Self.identified(id), url: url, description: description, aspectRatio: aspectRatio, fit: fit,
                width: width)
        }
    }

    /// How far apart pieces are, in points: never less than touching.
    private static func spaced(_ spacing: Double) throws(WidgetProblem) -> Double {
        guard spacing >= 0, spacing.isFinite else { throw .negativeSpacing(spacing) }
        return spacing
    }

    /// An id, which says something: one that's only spaces is no id.
    private static func identified(_ id: String?) throws(WidgetProblem) -> String? {
        guard let id else { return nil }
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .noID }
        return trimmed
    }

    /// Every button's label, in order.
    public var buttons: [String] {
        switch self {
        case .row(_, let items, _, _), .column(_, let items, _, _): items.flatMap(\.buttons)
        case .text, .image: []
        case .button(_, let label, _): [label]
        }
    }

    /// Every id given, in order.
    public var ids: [String] {
        switch self {
        case .row(let id, let items, _, _), .column(let id, let items, _, _):
            [id].compactMap { $0 } + items.flatMap(\.ids)
        case .text(let id, _, _, _), .button(let id, _, _), .image(let id, _, _, _, _, _): [id].compactMap { $0 }
        }
    }
}

/// Why a widget can't be shown.
public enum WidgetProblem: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    case noText
    case noLabel
    case sameLabel(String)
    case noID
    case negativeSpacing(Double)
    case notAWebAddress(String)
    case noDescription
    case noWidth(Double)
    case sameID(String)

    public var description: String {
        switch self {
        case .noText: "A text has no words: give it `words`."
        case .noLabel: "A button has no label: give it `label`."
        case .sameLabel(let label): "Two buttons say `\(label)`: each button needs a label of its own."
        case .noID: "An id is empty: give it one, or leave `id` out."
        case .negativeSpacing(let spacing): "A spacing is \(spacing): it's points apart, from 0."
        case .notAWebAddress(let url): "`\(url)` isn't a web address: a picture's url starts with https:// or http://."
        case .noDescription: "A picture has no description: say what it shows, in `description`."
        case .noWidth(let width): "A picture's width is \(width): it's points wide, more than 0, or leave `width` out."
        case .sameID(let id): "Two things have the id `\(id)`: each id is one thing's."
        }
    }
}
