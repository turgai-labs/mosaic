import Foundation

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

/// Pieces one after another, one under another or side by side, `spacing` points apart: each
/// child's id its own among them, one given none named by its kind and place.
public struct Stack: Identifiable, Codable, Equatable, Sendable {
    public internal(set) var id: PieceID
    public let children: [Widget]
    public var direction: Direction
    public var spacing: Points

    /// Which way it stacks, and how its pieces line up across it.
    public enum Direction: Codable, Equatable, Sendable {
        /// One under another, lined up across by their leading edges, centres or trailing edges.
        case vertical(alignment: HorizontalAlignment = .center)
        /// Side by side, lined up down by their tops, centres or bottoms.
        case horizontal(alignment: VerticalAlignment = .center)
    }

    public init(id: PieceID, _ direction: Direction, _ children: [Widget], spacing: Points = .standard)
        throws(WidgetProblem)
    {
        let children = Widget.placed(children)
        try Widget.distinct(children)
        self.id = id
        self.children = children
        self.direction = direction
        self.spacing = spacing
    }

    public init(id: String? = nil, _ direction: Direction, _ children: [Widget], spacing: Double = 12)
        throws(WidgetProblem)
    {
        try self.init(
            id: try id.map(PieceID.init) ?? PieceID(kind: "stack"), direction, children, spacing: Points(spacing))
    }

    public init(_ id: String, _ direction: Direction, _ children: [Widget], spacing: Double = 12)
        throws(WidgetProblem)
    {
        try self.init(id: PieceID(id), direction, children, spacing: Points(spacing))
    }

    private enum CodingKeys: CodingKey { case id, children, direction, spacing }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(PieceID.self, forKey: .id), container.decode(Direction.self, forKey: .direction),
            container.decode([Widget].self, forKey: .children), spacing: container.decode(Points.self, forKey: .spacing)
        )
    }
}

/// Items one under another, for long or growing collections: each built when it comes into view,
/// each item given an id, its own among them, since items move.
public struct List: Identifiable, Codable, Equatable, Sendable {
    public let id: PieceID
    public let items: [Widget]

    public init(id: PieceID, _ items: [Widget]) throws(WidgetProblem) {
        if let place = items.firstIndex(where: { !$0.id.isGiven }) { throw .itemWithoutID(place + 1) }
        try Widget.distinct(items)
        self.id = id
        self.items = items
    }

    public init(_ id: String, _ items: [Widget]) throws(WidgetProblem) {
        try self.init(id: PieceID(id), items)
    }

    private enum CodingKeys: CodingKey { case id, items }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(PieceID.self, forKey: .id), container.decode([Widget].self, forKey: .items))
    }
}

/// Cells in reading order, a fixed number to a row, every column the same width, `spacing` points
/// apart: for what lines up in columns, a calendar, a table, a keypad. A cell with nothing in it is
/// `nil`, so there's nothing to name. Each cell's id is its own among them, one given none named by
/// its kind and place.
public struct Grid: Identifiable, Codable, Equatable, Sendable {
    public internal(set) var id: PieceID
    public let columns: Columns
    public let cells: [Widget?]
    public var spacing: Points

    public init(id: PieceID, columns: Columns, _ cells: [Widget?], spacing: Points = .standard)
        throws(WidgetProblem)
    {
        let cells = Widget.placed(cells)
        try Widget.distinct(cells.compactMap { $0 })
        self.id = id
        self.columns = columns
        self.cells = cells
        self.spacing = spacing
    }

    public init(id: String? = nil, columns: Int, _ cells: [Widget?], spacing: Double = 12) throws(WidgetProblem) {
        try self.init(
            id: try id.map(PieceID.init) ?? PieceID(kind: "grid"), columns: Columns(columns), cells,
            spacing: Points(spacing))
    }

    public init(_ id: String, columns: Int, _ cells: [Widget?], spacing: Double = 12) throws(WidgetProblem) {
        try self.init(id: PieceID(id), columns: Columns(columns), cells, spacing: Points(spacing))
    }

    private enum CodingKeys: CodingKey { case id, columns, cells, spacing }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(PieceID.self, forKey: .id), columns: container.decode(Columns.self, forKey: .columns),
            container.decode([Widget?].self, forKey: .cells), spacing: container.decode(Points.self, forKey: .spacing))
    }
}

/// A line between what's before it and what's after: across a vertical stack, a list or a grid's
/// cell, down a horizontal stack.
public struct Divider: Identifiable, Codable, Equatable, Sendable {
    public internal(set) var id: PieceID

    public init(id: PieceID) {
        self.id = id
    }

    public init(_ id: String) throws(WidgetProblem) {
        self.init(id: try PieceID(id))
    }

    public init() {
        self.init(id: PieceID(kind: "divider"))
    }
}

/// Words to read, in a style and colour.
public struct Text: Identifiable, Codable, Equatable, Sendable {
    public internal(set) var id: PieceID
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

    public init(id: String? = nil, _ words: String, style: TextStyle = .body, color: TextColor = .primary)
        throws(WidgetProblem)
    {
        self.init(
            id: try id.map(PieceID.init) ?? PieceID(kind: "text"), words: try Words.of(words, or: .noText),
            style: style, color: color)
    }
}

/// A picture from the web, `description` saying what it shows, `width` points wide, or as wide as
/// there's room for.
public struct Image: Identifiable, Codable, Equatable, Sendable {
    public internal(set) var id: PieceID
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

    public init(
        id: String? = nil, address: String, description: String, aspectRatio: AspectRatio = .original,
        fit: ImageFit = .fit, width: Double? = nil
    ) throws(WidgetProblem) {
        self.init(
            id: try id.map(PieceID.init) ?? PieceID(kind: "image"), address: try WebAddress(address),
            description: try Words.of(description, or: .noDescription), aspectRatio: aspectRatio, fit: fit,
            width: try width.map { (width) throws(WidgetProblem) in try Width(width) })
    }
}

/// Something to press, by the id it's given: a press names it, so its name doesn't follow its place.
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

/// A widget: one of the pieces, each with its id; a stack, a grid or a list holds more. What's
/// only shown or holds others may be given no id, and is named by its kind and place among its
/// siblings; what a person acts on, and each item of a list, is given one.
public indirect enum Widget: Identifiable, Codable, Equatable, Sendable {
    case stack(Stack)
    case grid(Grid)
    case list(List)
    case divider(Divider)
    case text(Text)
    case image(Image)
    case button(Button)
    case textField(TextField)
    case toggle(Toggle)

    public var id: PieceID {
        switch self {
        case .stack(let piece): piece.id
        case .grid(let piece): piece.id
        case .list(let piece): piece.id
        case .divider(let piece): piece.id
        case .text(let piece): piece.id
        case .image(let piece): piece.id
        case .button(let piece): piece.id
        case .textField(let piece): piece.id
        case .toggle(let piece): piece.id
        }
    }

    /// What it holds: a stack's pieces, a grid's cells that hold something, a list's items, or
    /// nothing.
    public var children: [Widget] {
        switch self {
        case .stack(let stack): stack.children
        case .grid(let grid): grid.cells.compactMap { $0 }
        case .list(let list): list.items
        case .divider, .text, .image, .button, .textField, .toggle: []
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
    /// Siblings as what holds them has them: each given no id named by its kind and its place among
    /// them, an empty place counted.
    static func placed(_ siblings: [Widget?]) -> [Widget?] {
        siblings.enumerated().map { place, sibling in
            guard let sibling, !sibling.id.isGiven else { return sibling }
            switch sibling {
            case .stack(var piece):
                piece.id = PieceID(kind: "stack", place: place)
                return .stack(piece)
            case .grid(var piece):
                piece.id = PieceID(kind: "grid", place: place)
                return .grid(piece)
            case .divider(var piece):
                piece.id = PieceID(kind: "divider", place: place)
                return .divider(piece)
            case .text(var piece):
                piece.id = PieceID(kind: "text", place: place)
                return .text(piece)
            case .image(var piece):
                piece.id = PieceID(kind: "image", place: place)
                return .image(piece)
            case .list, .button, .textField, .toggle: return sibling
            }
        }
    }

    static func placed(_ siblings: [Widget]) -> [Widget] {
        placed(siblings.map(Optional.some)).compactMap { $0 }
    }

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
