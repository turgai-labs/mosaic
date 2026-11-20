import Foundation
import Mosaic
import Testing

/// A widget is whole before it's shown: everything in it says something, and each id is its own
/// among its siblings.
@Suite("A widget, checked")
struct WidgetTests {
    @Test(
        "a picture is from the web, and says what it shows",
        arguments: [
            ("file:///Users/me/secret.png", "a cover", WidgetProblem.notAWebAddress("file:///Users/me/secret.png")),
            ("cover.jpg", "a cover", .notAWebAddress("cover.jpg")),
            ("https://example.com/cover.jpg", " ", .noDescription),
        ])
    func picturesAreFromTheWeb(url: String, description: String, problem: WidgetProblem) {
        #expect(throws: problem) {
            try Widget.column(
                Column(id: "top", [.image(Image(id: "cover", url: URL(string: url)!, description: description))])
            )
            .checked()
        }
    }

    @Test("ids, words and labels are trimmed, and an id is its own among its siblings only")
    func idsAreTheirOwnAmongSiblings() throws {
        let checked = try Widget.column(
            Column(id: " top ", [.text(Text(id: "hi", "  Hi ")), .button(Button(id: "go", " Go "))])
        )
        .checked()
        #expect(checked == .column(Column(id: "top", [.text(Text(id: "hi", "Hi")), .button(Button(id: "go", "Go"))])))
        #expect(throws: WidgetProblem.noText) { try Widget.text(Text(id: "empty", " ")).checked() }
        #expect(throws: WidgetProblem.noID) { try Widget.text(Text(id: " ", "Hi")).checked() }
        #expect(throws: WidgetProblem.sameID("a")) {
            try Widget.row(Row(id: "r", [.text(Text(id: "a", "One")), .text(Text(id: "a ", "Two"))])).checked()
        }
        // The same id in two rows is two pieces: each is its own among its siblings.
        _ = try Widget.column(
            Column(
                id: "diary",
                [
                    .row(Row(id: "11-19", [.button(Button(id: "remove", "Remove"))])),
                    .row(Row(id: "11-20", [.button(Button(id: "remove", "Remove"))])),
                ])
        ).checked()
        #expect(throws: WidgetProblem.negativeSpacing(-1)) { try Widget.row(Row(id: "r", [], spacing: -1)).checked() }
    }

    @Test("a piece is found by its path, and a path is written and read back as text")
    func piecesAreFoundByPath() throws {
        let widget = Widget.column(
            Column(
                id: "today",
                [
                    .row(Row(id: "11/20", [.button(Button(id: "remove", "Remove"))]))
                ]))
        let path = PiecePath(["today", "11/20", "remove"])
        #expect(widget.widget(at: path) == .button(Button(id: "remove", "Remove")))
        #expect(widget.widget(at: PiecePath(["today", "11-21", "remove"])) == nil)
        #expect(path.description == "today/11%2F20/remove")
        #expect(PiecePath(path.description) == path)
        let event = Event(path: path, value: .flag(true))
        #expect(try JSONDecoder().decode(Event.self, from: JSONEncoder().encode(event)) == event)
    }
}
