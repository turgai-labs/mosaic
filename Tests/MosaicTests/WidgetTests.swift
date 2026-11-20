import Foundation
import Mosaic
import Testing

/// A widget is whole before it's shown: everything in it says something, and is its own.
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
            try Widget.column([.image(url: URL(string: url)!, description: description)]).checked()
        }
    }

    @Test("words and labels are trimmed, and each button's label and each id is its own")
    func everythingIsItsOwn() throws {
        #expect(
            try Widget.column([.text(words: "  Hi "), .button(label: " Go ")]).checked()
                == .column([.text(words: "Hi"), .button(label: "Go")]))
        #expect(throws: WidgetProblem.noText) { try Widget.column([.text(words: " ")]).checked() }
        #expect(throws: WidgetProblem.sameLabel("Go")) {
            try Widget.row([.button(label: "Go"), .column([.button(label: "Go ")])]).checked()
        }
        #expect(throws: WidgetProblem.sameID("a")) {
            try Widget.column([.text(id: "a", words: "One"), .text(id: " a", words: "Two")]).checked()
        }
        #expect(throws: WidgetProblem.negativeSpacing(-1)) { try Widget.row([], spacing: -1).checked() }
    }
}
