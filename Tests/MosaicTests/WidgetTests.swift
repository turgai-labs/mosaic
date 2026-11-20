import Foundation
import Mosaic
import Testing

/// A widget that exists can be shown: what's wrong with a piece stops it being made, here or decoded.
@Suite("A widget, made")
struct WidgetTests {
    @Test("a piece that says nothing, or is named by nothing, isn't made; what's made is trimmed")
    func piecesSaySomething() throws {
        #expect(try Text("  hi ", "  Hi ").words.rawValue == "Hi")
        #expect(try Text("  hi ", "Hi").id.rawValue == "hi")
        #expect(throws: WidgetProblem.noText) { try Text("hi", " ") }
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
            try Row("r", [.text(try Text("a", "One")), .text(try Text("a ", "Two"))])
        }
        // The same id in two rows is two pieces.
        _ = try Column(
            "diary",
            [
                .row(try Row("11-19", [.button(try Button("remove", "Remove"))])),
                .row(try Row("11-20", [.button(try Button("remove", "Remove"))])),
            ])
        #expect(throws: WidgetProblem.negativeSpacing(-1)) { try Row("r", [], spacing: -1) }
    }

    @Test("a widget decodes as it was made, and one that couldn't be made doesn't decode")
    func decodingMakesWhatMakingWould() throws {
        let widget = Widget.column(
            try Column(
                "today",
                [
                    .text(try Text("day", "Cycle day 3", style: .title)),
                    .image(
                        try Image("cover", address: "https://example.com/c.jpg", description: "A cover", width: 120)),
                    .toggle(try Toggle("reminder", "Daily reminder", isOn: true)),
                ]))
        let data = try JSONEncoder().encode(widget)
        #expect(try JSONDecoder().decode(Widget.self, from: data) == widget)
        let twice = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"cover\"", with: "\"day\"")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Widget.self, from: Data(twice.utf8)) }
        let blank = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\"Cycle day 3\"", with: "\" \"")
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Widget.self, from: Data(blank.utf8)) }
    }

    @Test("a piece is found by its path, and a path is written and read back as text")
    func piecesAreFoundByPath() throws {
        let widget = Widget.column(
            try Column("today", [.row(try Row("11/20", [.button(try Button("remove", "Remove"))]))]))
        let path = try #require(PiecePath("today/11%2F20/remove"))
        #expect(widget.widget(at: path) == .button(try Button("remove", "Remove")))
        #expect(widget.widget(at: try #require(PiecePath("today/11-21/remove"))) == nil)
        #expect(path.description == "today/11%2F20/remove")
        #expect(PiecePath("today//remove") == nil)
        let event = Event(path: path, value: .flag(true))
        #expect(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event)) == event)
    }
}
