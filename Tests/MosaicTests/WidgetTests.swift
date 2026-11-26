import Foundation
import Mosaic
import Testing

/// A widget that exists can be shown: what's wrong with a piece stops it being made, here or decoded.
@Suite("A widget, made")
struct WidgetTests {
    @Test("a button or toggle that says nothing, or a piece named by nothing, isn't made; a text says what it's given")
    func piecesSaySomething() throws {
        #expect(try Text("  hi ", "Hi").id.rawValue == "hi")
        // Any words, none too, as they're given, as SwiftUI's own Text takes them.
        #expect(try Text("hi", "  Hi ").words == "  Hi ")
        #expect(try Text("hi", "").words == "")
        #expect(throws: WidgetProblem.noLabel) { try Button("go", "") }
        #expect(throws: WidgetProblem.noLabel) { try Toggle("on", "\n", isOn: true) }
        #expect(throws: WidgetProblem.noID) { try Text(" ", "Hi") }
    }

    @Test(
        "a picture is from the web, says what it shows, and is wide if it says how wide",
        arguments: [
            (
                "file:///Users/me/secret.png", "a cover", 10.0,
                WidgetProblem.notAWebAddress("file:///Users/me/secret.png")
            ),
            ("cover.jpg", "a cover", 10, .notAWebAddress("cover.jpg")),
            ("https://example.com/cover.jpg", " ", 10, .noDescription),
            ("https://example.com/cover.jpg", "a cover", 0, .noWidth(0)),
        ])
    func picturesAreFromTheWeb(address: String, description: String, width: Double, problem: WidgetProblem) {
        #expect(throws: problem) { try Image("cover", address: address, description: description, width: width) }
    }

    @Test("an id is its own among its siblings only, and spacing is from 0")
    func idsAreTheirOwnAmongSiblings() throws {
        #expect(throws: WidgetProblem.sameID("a")) {
            try Stack("r", .horizontal(), [.text(try Text("a", "One")), .text(try Text("a ", "Two"))])
        }
        #expect(throws: WidgetProblem.sameID("day")) {
            try List("days", [.text(try Text("day", "Monday")), .text(try Text("day", "Tuesday"))])
        }
        // The same id in two rows is two pieces.
        _ = try List(
            "diary",
            [
                .stack(try Stack("11-19", .horizontal(), [.button(try Button("remove", "Remove"))])),
                .stack(try Stack("11-20", .horizontal(), [.button(try Button("remove", "Remove"))])),
            ])
        #expect(throws: WidgetProblem.negativeSpacing(-1)) { try Stack("r", .horizontal(), [], spacing: -1) }
    }

    @Test("a grid has at least one column, its cells' ids are their own among them, and a cell may hold nothing")
    func gridsLineUpInColumns() throws {
        #expect(throws: WidgetProblem.noColumns(0)) { try Grid("month", columns: 0, []) }
        #expect(throws: WidgetProblem.sameID("1")) {
            try Grid("month", columns: 7, [.text(try Text("1", "1")), nil, .text(try Text("1", "1"))])
        }
        #expect(throws: WidgetProblem.negativeSpacing(-2)) { try Grid("month", columns: 7, [], spacing: -2) }
        // Empty cells have no id to share: any number of them, anywhere.
        let month = try Grid(
            "month", columns: 7, [nil, nil, .text(try Text("1", "1")), nil, .text(try Text("2", "2"))])
        #expect(month.cells.count == 5)
        let widget = Widget.grid(month)
        #expect(widget.children.map(\.id.rawValue) == ["1", "2"])
        #expect(widget.widget(at: try #require(PiecePath("month/2"))) == .text(try Text("2", "2")))
        // A cell is any piece: a stack with a line across it.
        _ = try Grid(
            "keys", columns: 2,
            [.stack(try Stack("a", .vertical(), [.text(try Text("top", "A")), .divider(try Divider("line"))]))])
        #expect(throws: WidgetProblem.noID) { try Divider(" ") }
    }

    @Test("a piece given no id is named by its kind and place by what holds it; a list's items are each given one")
    func unnamedPiecesAreNamedByPlace() throws {
        let stack = try Stack(
            .vertical(),
            [
                .text(try Text("Today", style: .title)),
                .divider(Divider()),
                .text(try Text("note", "Slept well")),
                .button(try Button("log", "Log")),
                .stack(try Stack(.horizontal(), [.text(try Text("One")), .text(try Text("Two"))])),
                .image(try Image(address: "https://example.com/c.jpg", description: "A cover")),
            ])
        #expect(stack.id.rawValue == "#stack")
        #expect(
            stack.children.map(\.id.rawValue) == ["#text-1", "#divider-2", "note", "log", "#stack-5", "#image-6"])
        #expect(stack.children[4].children.map(\.id.rawValue) == ["#text-1", "#text-2"])
        // Found by the path its place gives it.
        let widget = Widget.stack(stack)
        #expect(widget.widget(at: try #require(PiecePath("%23stack/%23stack-5/%23text-2"))) != nil)
        // A grid counts its empty cells, so a cell keeps its name whatever is before it.
        let grid = try Grid(columns: 7, [nil, nil, .text(try Text("1")), .button(try Button("2", "2"))])
        #expect(grid.cells.compactMap { $0?.id.rawValue } == ["#text-3", "2"])
        // Written out and read back, it's the same widget, and holds the names it had.
        let read = try JSONDecoder().decode(Widget.self, from: JSONEncoder().encode(widget))
        #expect(read == widget)
        // A list's items move, so place doesn't name them.
        #expect(throws: WidgetProblem.itemWithoutID(2)) {
            try List("days", [.text(try Text("mon", "Monday")), .text(try Text("Tuesday"))])
        }
        // What holds unnamed pieces can be an item, by its own id.
        _ = try List(
            "days", [.stack(try Stack("mon", .horizontal(), [.text(try Text("Monday")), .divider(Divider())]))])
    }

    @Test("a widget decodes as it was made, and one that couldn't be made doesn't decode")
    func decodingMakesWhatMakingWould() throws {
        let widget = Widget.stack(
            try Stack(
                "today", .vertical(),
                [
                    .text(try Text("day", "Cycle day 3", style: .title)),
                    .image(
                        try Image("cover", address: "https://example.com/c.jpg", description: "A cover", width: 120)),
                    .toggle(try Toggle("reminder", "Daily reminder", isOn: true)),
                    .list(try List("notes", [.text(try Text("first", "Slept well"))])),
                    .divider(try Divider("line")),
                    .grid(try Grid("week", columns: 7, [nil, .text(try Text("mon", "Mon"))], spacing: 2)),
                    .stack(try Stack("end", .horizontal(alignment: .bottom), [], spacing: 4)),
                ]))
        let data = try JSONEncoder().encode(widget)
        #expect(try JSONDecoder().decode(Widget.self, from: data) == widget)
        let noColumns = String(decoding: data, as: UTF8.self).replacingOccurrences(
            of: "\"columns\":7", with: "\"columns\":0")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Widget.self, from: Data(noColumns.utf8)) }
        let twice = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"cover\"", with: "\"day\"")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Widget.self, from: Data(twice.utf8)) }
        let blank = String(decoding: data, as: UTF8.self).replacingOccurrences(
            of: "\"Daily reminder\"", with: "\" \"")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Widget.self, from: Data(blank.utf8)) }
        // A text says what it's given, none too.
        let quiet = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"Cycle day 3\"", with: "\"\"")
        #expect(try JSONDecoder().decode(Widget.self, from: Data(quiet.utf8)) != widget)
    }

    @Test("a piece is found by its path, and a path is written and read back as text")
    func piecesAreFoundByPath() throws {
        let widget = Widget.stack(
            try Stack("today", .vertical(), [.list(try List("11/20", [.button(try Button("remove", "Remove"))]))]))
        let path = try #require(PiecePath("today/11%2F20/remove"))
        #expect(widget.widget(at: path) == .button(try Button("remove", "Remove")))
        #expect(widget.widget(at: try #require(PiecePath("today/11-21/remove"))) == nil)
        #expect(path.description == "today/11%2F20/remove")
        #expect(PiecePath("today//remove") == nil)
        let event = Event(path: path, value: .flag(true))
        #expect(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event)) == event)
    }
}
