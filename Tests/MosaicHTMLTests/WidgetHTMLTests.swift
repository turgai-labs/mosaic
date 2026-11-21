import Elementary
import Foundation
import Mosaic
import MosaicHTML
import Testing

/// A widget shown after another animates from it: each piece named by its path, the same piece named
/// the same in both.
@Suite("A widget, as HTML")
struct WidgetHTMLTests {
    let press: @Sendable (PiecePath, Int) -> String = { path, version in "press?path=\(path)&page=\(version)" }

    @Test("each piece is named by its path, slides by the edges its box lines it up by, and a press names its path")
    func piecesAreNamedByTheirPaths() throws {
        let widget = Widget.stack(
            try Stack(
                "top", .vertical(),
                [
                    .text(try Text("now playing", "Song", style: .title)),
                    .image(
                        try Image(
                            "cover", address: "https://example.com/cover.jpg", description: "The album's cover",
                            aspectRatio: .square, fit: .fill, width: 120)),
                    .stack(
                        try Stack(
                            "controls", .horizontal(alignment: .top),
                            [
                                .button(try Button("play", "Play", kind: .prominent)),
                                .button(try Button("next", "Next")),
                            ],
                            spacing: 6)),
                    .textField(try TextField("note", text: "Loud", placeholder: "A note")),
                    .toggle(try Toggle("repeat", "Repeat", isOn: true)),
                    .list(try List("queue", [.text(try Text("next song", "Next song"))])),
                ]))
        let html = WidgetDocument(widget, version: 1, title: "Website", live: "live", press: press).render()
        #expect(html.contains("Idiomorph.morph(page, html"))
        #expect(html.contains(#"<main data-live="live">"#), "\(html)")
        #expect(html.contains("addEventListener('\(WidgetDocument.liveEvent)'"))
        for name in ["p-top", "p-top_2f_now_25_20playing", "p-top_2f_cover", "p-top_2f_controls_2f_play"] {
            #expect(html.contains("id=\"\(name)\""), "\(name) in \(html)")
        }
        #expect(html.contains(#"class="title primary" data-anchor="center top""#), "\(html)")
        #expect(html.contains(#"data-press="press?path=top/controls/play&amp;page=1""#), "\(html)")
        #expect(html.contains(#"class="stack horizontal top" style="gap: 6px"#))
        #expect(
            html.contains(
                #"src="https://example.com/cover.jpg" alt="The album's cover" loading="lazy" class="image fill" style="aspect-ratio: 1 / 1; width: 120px; "#
            ), "\(html)")
        #expect(html.contains(#"value="Loud""#) && html.contains(#"placeholder="A note""#), "\(html)")
        #expect(html.contains("checked"), "\(html)")
        #expect(html.contains(#"id="p-top_2f_queue" class="list""#), "\(html)")
        #expect(html.contains(#"id="p-top" class="stack vertical center""#), "\(html)")
        let lined = WidgetView(
            .stack(
                try Stack(
                    "top", .vertical(),
                    [
                        .stack(try Stack("left", .vertical(alignment: .leading), [.text(try Text("words", "Left"))])),
                        .stack(try Stack("low", .horizontal(alignment: .bottom), [.button(try Button("go", "Go"))])),
                    ])), version: 1, press: press
        ).render()
        #expect(
            lined.contains(#"id="p-top_2f_left_2f_words" class="body primary" data-anchor="leading top""#), "\(lined)")
        #expect(lined.contains(#"data-anchor="leading bottom""#), "\(lined)")
    }
}
