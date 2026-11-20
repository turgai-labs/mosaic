public import Foundation

// MARK: Paths

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
            guard let id = String(part).removingPercentEncoding.flatMap({ try? PieceID($0) }) else { return nil }
            ids.append(id)
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

/// Pieces one under another, top to bottom, aligned, `spacing` points apart: each child's id its own
/// among them.
public struct Column: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public let children: [Widget]
    public var alignment: ColumnAlignment
    public var spacing: Points

    public init(id: PieceID, _ children: [Widget], alignment: ColumnAlignment = .center, spacing: Points = .standard)
        throws(WidgetProblem)
    {
        try Widget.distinct(children)
        self.id = id
        self.children = children
        self.alignment = alignment
        self.spacing = spacing
    }

    public init(_ id: String, _ children: [Widget], alignment: ColumnAlignment = .center, spacing: Double = 12)
        throws(WidgetProblem)
    {
        try self.init(id: PieceID(id), children, alignment: alignment, spacing: Points(spacing))
    }

    private enum CodingKeys: CodingKey { case id, children, alignment, spacing }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(PieceID.self, forKey: .id), container.decode([Widget].self, forKey: .children),
            alignment: container.decode(ColumnAlignment.self, forKey: .alignment),
            spacing: container.decode(Points.self, forKey: .spacing))
    }
}

/// Pieces side by side, left to right, aligned, `spacing` points apart: each child's id its own
/// among them.
public struct Row: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public let children: [Widget]
    public var alignment: RowAlignment
    public var spacing: Points

    public init(id: PieceID, _ children: [Widget], alignment: RowAlignment = .center, spacing: Points = .standard)
        throws(WidgetProblem)
    {
        try Widget.distinct(children)
        self.id = id
        self.children = children
        self.alignment = alignment
        self.spacing = spacing
    }

    public init(_ id: String, _ children: [Widget], alignment: RowAlignment = .center, spacing: Double = 12)
        throws(WidgetProblem)
    {
        try self.init(id: PieceID(id), children, alignment: alignment, spacing: Points(spacing))
    }

    private enum CodingKeys: CodingKey { case id, children, alignment, spacing }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(PieceID.self, forKey: .id), container.decode([Widget].self, forKey: .children),
            alignment: container.decode(RowAlignment.self, forKey: .alignment),
            spacing: container.decode(Points.self, forKey: .spacing))
    }
}

/// Words to read, in a style and colour.
public struct Text: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var words: Words
    public var style: TextStyle
    public var color: TextColor

    public init(id: PieceID, words: Words, style: TextStyle = .body, color: TextColor = .primary) {
        self.id = id
        self.words = words
        self.style = style
        self.color = color
    }

    public init(_ id: String, _ words: String, style: TextStyle = .body, color: TextColor = .primary)
        throws(WidgetProblem)
    {
        self.init(id: try PieceID(id), words: try Words.of(words, or: .noText), style: style, color: color)
    }
}

/// A picture from the web, `description` saying what it shows, `width` points wide, or as wide as
/// there's room for.
public struct Image: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var address: WebAddress
    public var description: Words
    public var aspectRatio: AspectRatio
    public var fit: ImageFit
    public var width: Width?

    public init(
        id: PieceID, address: WebAddress, description: Words, aspectRatio: AspectRatio = .original,
        fit: ImageFit = .fit, width: Width? = nil
    ) {
        self.id = id
        self.address = address
        self.description = description
        self.aspectRatio = aspectRatio
        self.fit = fit
        self.width = width
    }

    public init(
        _ id: String, address: String, description: String, aspectRatio: AspectRatio = .original,
        fit: ImageFit = .fit, width: Double? = nil
    ) throws(WidgetProblem) {
        self.init(
            id: try PieceID(id), address: try WebAddress(address),
            description: try Words.of(description, or: .noDescription), aspectRatio: aspectRatio, fit: fit,
            width: try width.map { (width) throws(WidgetProblem) in try Width(width) })
    }
}

/// Something to press.
public struct Button: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var label: Words
    public var kind: ButtonKind

    public init(id: PieceID, label: Words, kind: ButtonKind = .normal) {
        self.id = id
        self.label = label
        self.kind = kind
    }

    public init(_ id: String, _ label: String, kind: ButtonKind = .normal) throws(WidgetProblem) {
        self.init(id: try PieceID(id), label: try Words.of(label, or: .noLabel), kind: kind)
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

    public init(_ id: String, text: String, placeholder: String) throws(WidgetProblem) {
        self.init(id: try PieceID(id), text: text, placeholder: placeholder)
    }
}

/// On or off.
public struct Toggle: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public var label: Words
    public var isOn: Bool

    public init(id: PieceID, label: Words, isOn: Bool) {
        self.id = id
        self.label = label
        self.isOn = isOn
    }

    public init(_ id: String, _ label: String, isOn: Bool) throws(WidgetProblem) {
        self.init(id: try PieceID(id), label: try Words.of(label, or: .noLabel), isOn: isOn)
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

extension Widget {
    /// Siblings, each id its own among them.
    static func distinct(_ children: [Widget]) throws(WidgetProblem) {
        var ids: Set<PieceID> = []
        for child in children where !ids.insert(child.id).inserted { throw .sameID(child.id.rawValue) }
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
