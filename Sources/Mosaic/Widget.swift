public import Foundation

// MARK: Ids

/// A piece's name: unique among its siblings.
public struct PieceID: Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.init(value) }

    public init(from decoder: any Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

/// Where a piece is: the ids from the widget's top down to it.
public struct PiecePath: Hashable, Codable, Sendable, CustomStringConvertible {
    public let ids: [PieceID]

    public init(_ ids: [PieceID]) { self.ids = ids }

    /// The path of a child of this piece.
    public func appending(_ id: PieceID) -> PiecePath { PiecePath(ids + [id]) }

    /// As text: each id percent-encoded, joined by `/`.
    public var description: String {
        ids.map { $0.rawValue.addingPercentEncoding(withAllowedCharacters: Self.unreserved) ?? "" }
            .joined(separator: "/")
    }

    /// The path written as ``description`` writes it.
    public init?(_ text: String) {
        var ids: [PieceID] = []
        for part in text.split(separator: "/", omittingEmptySubsequences: false) {
            guard let id = String(part).removingPercentEncoding, !id.isEmpty else { return nil }
            ids.append(PieceID(id))
        }
        self.init(ids)
    }

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let path = PiecePath(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "No path: \(text)"))
        }
        self = path
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    private static let unreserved = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~")
}

// MARK: Pieces

/// Pieces one under another, top to bottom, aligned, `spacing` points apart.
public struct Column: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var children: [Widget]
    public var alignment: ColumnAlignment
    public var spacing: Double

    public init(id: PieceID, _ children: [Widget], alignment: ColumnAlignment = .center, spacing: Double = 12) {
        self.id = id
        self.children = children
        self.alignment = alignment
        self.spacing = spacing
    }
}

/// Pieces side by side, left to right, aligned, `spacing` points apart.
public struct Row: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var children: [Widget]
    public var alignment: RowAlignment
    public var spacing: Double

    public init(id: PieceID, _ children: [Widget], alignment: RowAlignment = .center, spacing: Double = 12) {
        self.id = id
        self.children = children
        self.alignment = alignment
        self.spacing = spacing
    }
}

/// Words to read, in a style and colour.
public struct Text: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var words: String
    public var style: TextStyle
    public var color: TextColor

    public init(id: PieceID, _ words: String, style: TextStyle = .body, color: TextColor = .primary) {
        self.id = id
        self.words = words
        self.style = style
        self.color = color
    }
}

/// A picture from the web, `description` saying what it shows, `width` points wide, or as wide as
/// there's room for.
public struct Image: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var url: URL
    public var description: String
    public var aspectRatio: AspectRatio
    public var fit: ImageFit
    public var width: Double?

    public init(
        id: PieceID, url: URL, description: String, aspectRatio: AspectRatio = .original, fit: ImageFit = .fit,
        width: Double? = nil
    ) {
        self.id = id
        self.url = url
        self.description = description
        self.aspectRatio = aspectRatio
        self.fit = fit
        self.width = width
    }
}

/// Something to press.
public struct Button: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var label: String
    public var kind: ButtonKind

    public init(id: PieceID, _ label: String, kind: ButtonKind = .normal) {
        self.id = id
        self.label = label
        self.kind = kind
    }
}

/// Words to type.
public struct TextField: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var text: String
    public var placeholder: String

    public init(id: PieceID, text: String, placeholder: String) {
        self.id = id
        self.text = text
        self.placeholder = placeholder
    }
}

/// On or off.
public struct Toggle: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var label: String
    public var isOn: Bool

    public init(id: PieceID, _ label: String, isOn: Bool) {
        self.id = id
        self.label = label
        self.isOn = isOn
    }
}

// MARK: Widget

/// A widget: one of the pieces, each with its id; a column or a row holds more.
public indirect enum Widget: Identifiable, Codable, Equatable, Sendable {
    case column(Column)
    case row(Row)
    case text(Text)
    case image(Image)
    case button(Button)
    case textField(TextField)
    case toggle(Toggle)

    public var id: PieceID {
        switch self {
        case .column(let piece): piece.id
        case .row(let piece): piece.id
        case .text(let piece): piece.id
        case .image(let piece): piece.id
        case .button(let piece): piece.id
        case .textField(let piece): piece.id
        case .toggle(let piece): piece.id
        }
    }

    /// What it holds: a column's or a row's pieces, or nothing.
    public var children: [Widget] {
        switch self {
        case .column(let column): column.children
        case .row(let row): row.children
        case .text, .image, .button, .textField, .toggle: []
        }
    }

    /// The piece at `path`, which starts with this widget's own id.
    public func widget(at path: PiecePath) -> Widget? {
        guard let first = path.ids.first, first == id else { return nil }
        var found = self
        for id in path.ids.dropFirst() {
            guard let child = found.children.first(where: { $0.id == id }) else { return nil }
            found = child
        }
        return found
    }
}

// MARK: Checked

extension Widget {
    /// The widget as it's shown: every id, text and label there and trimmed, each id its own among
    /// its siblings, every picture from the web saying what it shows, and every spacing and width a
    /// real one.
    public func checked() throws(WidgetProblem) -> Widget {
        switch self {
        case .column(var column):
            column = Column(
                id: try Self.named(column.id), try Self.checked(column.children), alignment: column.alignment,
                spacing: try Self.spaced(column.spacing))
            return .column(column)
        case .row(var row):
            row = Row(
                id: try Self.named(row.id), try Self.checked(row.children), alignment: row.alignment,
                spacing: try Self.spaced(row.spacing))
            return .row(row)
        case .text(let text):
            let words = text.words.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !words.isEmpty else { throw .noText }
            return .text(Text(id: try Self.named(text.id), words, style: text.style, color: text.color))
        case .image(let image):
            guard ["http", "https"].contains(image.url.scheme?.lowercased() ?? ""), image.url.host != nil else {
                throw .notAWebAddress(image.url.absoluteString)
            }
            let description = image.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !description.isEmpty else { throw .noDescription }
            if let width = image.width { guard width > 0, width.isFinite else { throw .noWidth(width) } }
            return .image(
                Image(
                    id: try Self.named(image.id), url: image.url, description: description,
                    aspectRatio: image.aspectRatio, fit: image.fit, width: image.width))
        case .button(let button):
            let label = button.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw .noLabel }
            return .button(Button(id: try Self.named(button.id), label, kind: button.kind))
        case .textField(let field):
            return .textField(TextField(id: try Self.named(field.id), text: field.text, placeholder: field.placeholder))
        case .toggle(let toggle):
            let label = toggle.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { throw .noLabel }
            return .toggle(Toggle(id: try Self.named(toggle.id), label, isOn: toggle.isOn))
        }
    }

    /// Siblings, each checked, each id its own among them.
    private static func checked(_ children: [Widget]) throws(WidgetProblem) -> [Widget] {
        var checked: [Widget] = []
        var ids: Set<PieceID> = []
        for child in children {
            let child = try child.checked()
            guard ids.insert(child.id).inserted else { throw .sameID(child.id.rawValue) }
            checked.append(child)
        }
        return checked
    }

    /// An id, which says something: one that's only spaces is no id.
    private static func named(_ id: PieceID) throws(WidgetProblem) -> PieceID {
        let trimmed = id.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .noID }
        return PieceID(trimmed)
    }

    /// How far apart pieces are, in points: never less than touching.
    private static func spaced(_ spacing: Double) throws(WidgetProblem) -> Double {
        guard spacing >= 0, spacing.isFinite else { throw .negativeSpacing(spacing) }
        return spacing
    }
}

/// Why a widget can't be shown.
public enum WidgetProblem: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    case noText
    case noLabel
    case noID
    case sameID(String)
    case negativeSpacing(Double)
    case notAWebAddress(String)
    case noDescription
    case noWidth(Double)

    public var description: String {
        switch self {
        case .noText: "A text has no words: give it `words`."
        case .noLabel: "A button or a toggle has no label: give it `label`."
        case .noID: "An id is empty: give it one."
        case .sameID(let id): "Two things side by side have the id `\(id)`: each id is one thing's among its siblings."
        case .negativeSpacing(let spacing): "A spacing is \(spacing): it's points apart, from 0."
        case .notAWebAddress(let url): "`\(url)` isn't a web address: a picture's url starts with https:// or http://."
        case .noDescription: "A picture has no description: say what it shows, in `description`."
        case .noWidth(let width): "A picture's width is \(width): it's points wide, more than 0, or leave `width` out."
        }
    }
}

// MARK: Events

/// What a person did, and where.
public struct Event: Codable, Equatable, Sendable {
    /// The piece it happened to.
    public let path: PiecePath
    /// What it came to: nothing for a press, the text for a text field, on or off for a toggle.
    public let value: Value?

    public init(path: PiecePath, value: Value? = nil) {
        self.path = path
        self.value = value
    }
}

/// A value an event carries.
public enum Value: Codable, Equatable, Sendable {
    case text(String)
    case flag(Bool)
}
