import Elementary
import Foundation
import Mosaic
import MosaicHTML
import Testing

/// A widget shown after another animates from it: each thing named by what it is, the same thing
/// named the same in both.
@Suite("A widget, as HTML")
struct WidgetHTMLTests {
    let press: @Sendable (String, Int) -> String = { label, version in "press?label=\(label)&page=\(version)" }

    @Test("the morph keeps each thing by its id, a button by its label, the rest by place; only an id makes it slide")
    func thingsAreKeptByWhatTheyAre() {
        let widget = Widget.column([
            .text(id: "now playing", words: "Song", style: .title), .text(words: "from Music"),
            .image(
                url: URL(string: "https://example.com/cover.jpg")!, description: "The album's cover",
                aspectRatio: .square, fit: .fill, width: 120),
            .row([.button(label: "Play", kind: .prominent), .button(label: "Next")], alignment: .top, spacing: 6),
        ])
        let html = WidgetDocument(widget, version: 1, title: "Website", live: "live", press: press).render()
        #expect(html.contains("Idiomorph.morph(page, html"))
        #expect(html.contains(#"<main data-live="live">"#), "\(html)")
        #expect(html.contains("addEventListener('\(WidgetDocument.liveEvent)'"))
        // An id given, a button's label, or else the place, as the morph keeps it.
        for name in ["item", "id-now_20_playing", "item-1", "item-2", "item-3", "label-Play", "label-Next"] {
            #expect(html.contains("id=\"\(name)\""), "\(name)")
        }
        // Only an id given makes it slide, by the edges its box lines it up by; the rest fade.
        #expect(html.components(separatedBy: "data-anchor=").count == 2)
        #expect(html.contains(#"id="id-now_20_playing" class="title primary" data-anchor="center top""#), "\(html)")
        let lined = WidgetView(
            .column([
                .column([.text(id: "left", words: "Left")], alignment: .leading),
                .row([.button(id: "low", label: "Low")], alignment: .bottom),
            ]), version: 1, press: press
        ).render()
        #expect(lined.contains(#"id="id-left" class="body primary" data-anchor="leading top""#), "\(lined)")
        #expect(lined.contains(#"data-anchor="leading bottom""#), "\(lined)")
        // A press goes where the host says, for the version shown.
        #expect(html.contains(#"data-press="press?label=Play&amp;page=1""#), "\(html)")
        #expect(html.contains(#"class="title primary""#))
        #expect(html.contains(#"class="prominent""#))
        #expect(html.contains(#"class="normal""#))
        #expect(html.contains(#"class="row top" style="gap: 6px"#))
        #expect(
            html.contains(
                #"src="https://example.com/cover.jpg" alt="The album's cover" loading="lazy" class="image fill" style="aspect-ratio: 1 / 1; width: 120px; "#
            ), "\(html)")
        #expect(html.contains(#"class="column center" style="gap: 12px"#))
    }
}
