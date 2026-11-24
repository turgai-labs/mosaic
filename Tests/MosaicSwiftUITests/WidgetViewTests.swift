#if canImport(SwiftUI)
    import Mosaic
    import MosaicSwiftUI
    import SwiftUI
    import Testing

    /// A widget with every piece is drawn with SwiftUI.
    @Suite("A widget, drawn with SwiftUI")
    @MainActor
    struct WidgetViewTests {
        static func every() throws -> Mosaic.Widget {
            .stack(
                try Mosaic.Stack(
                    "top", .vertical(alignment: .leading),
                    [
                        .text(try Mosaic.Text("title", "Coffee", style: .title)),
                        .text(try Mosaic.Text("note", "2 ordered", style: .caption, color: .secondary)),
                        .divider(Mosaic.Divider()),
                        .grid(
                            try Mosaic.Grid(
                                "days", columns: 3,
                                [
                                    nil, .text(try Mosaic.Text("1", "1")),
                                    .button(try Mosaic.Button("2", "2")),
                                    .text(try Mosaic.Text("3", "3")),
                                ])),
                        .stack(
                            try Mosaic.Stack(
                                "actions", .horizontal(),
                                [
                                    .button(try Mosaic.Button("order", "Order", kind: .prominent)),
                                    .button(try Mosaic.Button("cancel", "Cancel", kind: .destructive)),
                                ])),
                        .list(try Mosaic.List("orders", [.text(try Mosaic.Text("first", "Espresso"))])),
                        .textField(try Mosaic.TextField("name", text: "", placeholder: "Name")),
                        .toggle(try Mosaic.Toggle("sugar", "Sugar", isOn: true)),
                        .image(
                            try Mosaic.Image(
                                "cup", address: "https://example.com/cup.png", description: "A cup",
                                aspectRatio: .square, width: 80)),
                    ]))
        }

        @Test func everyPieceIsDrawn() throws {
            let renderer = ImageRenderer(content: WidgetView(try Self.every()) { _ in }.frame(width: 320))
            let image = try #require(renderer.cgImage)
            #expect(image.width > 0 && image.height > 0)
        }
    }
#endif
