#if canImport(SwiftUI) && DEBUG
    import Mosaic
    import SwiftUI

    #Preview("Every piece") {
        if let widget = try? previewWidget() {
            WidgetView(widget) { path in print("pressed \(path)") }.padding().frame(width: 360)
        }
    }

    /// A widget with every piece, to look at.
    private func previewWidget() throws -> Mosaic.Widget {
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
                                nil, .text(try Mosaic.Text("1", "1")), .button(try Mosaic.Button("2", "2")),
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
                ]))
    }
#endif
