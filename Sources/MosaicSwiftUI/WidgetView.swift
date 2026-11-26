#if canImport(SwiftUI)
    public import Mosaic
    public import SwiftUI

    /// A widget, drawn with SwiftUI: each piece as the platform draws its kind. A press of a button
    /// is told by the button's path, as the host takes it. It draws what the widget says and decides
    /// nothing; each piece keeps its identity by its id, so a widget shown after another changes
    /// only what changed.
    public struct WidgetView: View {
        let widget: Mosaic.Widget
        /// Where it is: the ids from the widget's top down to it.
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        /// `widget`, from its top, telling `press` the path of each button pressed.
        public init(_ widget: Mosaic.Widget, press: @escaping @MainActor (_ path: PiecePath) -> Void) {
            self.init(widget, at: PiecePath([widget.id]), press: press)
        }

        init(_ widget: Mosaic.Widget, at path: PiecePath, press: @escaping @MainActor (PiecePath) -> Void) {
            self.widget = widget
            self.path = path
            self.press = press
        }

        public var body: some View {
            switch widget {
            case .stack(let stack): StackView(stack: stack, path: path, press: press)
            case .grid(let grid): GridView(grid: grid, path: path, press: press)
            case .list(let list): ListView(list: list, path: path, press: press)
            case .divider: SwiftUI.Divider()
            case .text(let text): TextView(text: text)
            case .image(let image): ImageView(image: image)
            case .button(let button): ButtonView(button: button, path: path, press: press)
            case .textField(let field): FieldView(field: field)
            case .toggle(let toggle): ToggleView(toggle: toggle)
            }
        }
    }

    /// Pieces one under another or side by side, lined up and spaced as the stack says.
    struct StackView: View {
        let stack: Mosaic.Stack
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            switch stack.direction {
            case .vertical(let alignment):
                VStack(alignment: .init(alignment), spacing: stack.spacing.rawValue) {
                    ChildrenView(children: stack.children, path: path, press: press)
                }
            case .horizontal(let alignment):
                HStack(alignment: .init(alignment), spacing: stack.spacing.rawValue) {
                    ChildrenView(children: stack.children, path: path, press: press)
                }
            }
        }
    }

    /// Children, each by its id, at its path.
    struct ChildrenView: View {
        let children: [Mosaic.Widget]
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            ForEach(children) { child in
                WidgetView(child, at: path.appending(child.id), press: press)
            }
        }
    }

    /// Cells in rows of the grid's columns, every column as wide as the others; an empty cell holds
    /// its place.
    struct GridView: View {
        let grid: Mosaic.Grid
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            SwiftUI.Grid(horizontalSpacing: grid.spacing.rawValue, verticalSpacing: grid.spacing.rawValue) {
                ForEach(rows, id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { place in
                            CellView(cell: grid.cells[place], path: path, press: press)
                        }
                    }
                }
            }
        }

        /// The cells' places, a row of the grid's columns to each, the last as full as there are cells.
        private var rows: [[Int]] {
            stride(from: 0, to: grid.cells.count, by: grid.columns.rawValue).map { start in
                Array(start..<min(start + grid.columns.rawValue, grid.cells.count))
            }
        }
    }

    /// A grid's cell: what's in it, as wide as its column lets it be, or nothing, holding its place.
    struct CellView: View {
        let cell: Mosaic.Widget?
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            if let cell {
                WidgetView(cell, at: path.appending(cell.id), press: press).frame(maxWidth: .infinity)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
        }
    }

    /// Items one under another, each built when it comes into view.
    struct ListView: View {
        let list: Mosaic.List
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            LazyVStack(alignment: .leading, spacing: 12) {
                ChildrenView(children: list.items, path: path, press: press)
            }
        }
    }

    /// Words, in their style and colour.
    struct TextView: View {
        let text: Mosaic.Text

        var body: some View {
            SwiftUI.Text(text.words)
                .font(Font(text.style))
                .italic(text.style == .emphasis)
                .foregroundStyle(Color(text.color))
        }
    }

    /// A picture from the web, in its shape, filling it as it says, as wide as it says.
    struct ImageView: View {
        let image: Mosaic.Image

        var body: some View {
            AsyncImage(url: image.address.url) { loaded in
                loaded.resizable().aspectRatio(image.aspectRatio.ratio, contentMode: .init(image.fit))
            } placeholder: {
                Color.secondary.opacity(0.15).aspectRatio(image.aspectRatio.ratio ?? 1, contentMode: .fit)
            }
            .frame(width: image.width.map { CGFloat($0.rawValue) })
            .clipShape(.rect(cornerRadius: 8))
            .accessibilityLabel(image.description.rawValue)
        }
    }

    /// Something to press: the one most pressed stands out, one that removes or ends something says so.
    struct ButtonView: View {
        let button: Mosaic.Button
        let path: PiecePath
        let press: @MainActor (PiecePath) -> Void

        var body: some View {
            let pressed = SwiftUI.Button(
                button.label.rawValue, role: button.kind == .destructive ? .destructive : nil
            ) { press(path) }
            switch button.kind {
            case .prominent: pressed.buttonStyle(.borderedProminent)
            // Red, as it is wherever a widget is drawn: macOS doesn't colour a bordered one by its role.
            case .destructive: pressed.buttonStyle(.bordered).foregroundStyle(.red)
            case .normal: pressed.buttonStyle(.bordered)
            }
        }
    }

    /// Words to type, starting from what the field says. What's typed isn't told yet.
    struct FieldView: View {
        let field: Mosaic.TextField
        @State private var text: String

        init(field: Mosaic.TextField) {
            self.field = field
            _text = State(initialValue: field.text)
        }

        var body: some View {
            SwiftUI.TextField(field.placeholder, text: $text).textFieldStyle(.roundedBorder)
        }
    }

    /// On or off, starting as the toggle says. A change isn't told yet.
    struct ToggleView: View {
        let toggle: Mosaic.Toggle
        @State private var isOn: Bool

        init(toggle: Mosaic.Toggle) {
            self.toggle = toggle
            _isOn = State(initialValue: toggle.isOn)
        }

        var body: some View {
            SwiftUI.Toggle(toggle.label.rawValue, isOn: $isOn)
        }
    }

    // MARK: Styles, as SwiftUI has them

    extension SwiftUI.HorizontalAlignment {
        init(_ alignment: Mosaic.HorizontalAlignment) {
            switch alignment {
            case .leading: self = .leading
            case .center: self = .center
            case .trailing: self = .trailing
            }
        }
    }

    extension SwiftUI.VerticalAlignment {
        init(_ alignment: Mosaic.VerticalAlignment) {
            switch alignment {
            case .top: self = .top
            case .center: self = .center
            case .bottom: self = .bottom
            }
        }
    }

    extension Font {
        /// A text style: the platform's own, never a size.
        init(_ style: Mosaic.TextStyle) {
            switch style {
            case .title: self = .title.bold()
            case .heading: self = .headline
            case .body: self = .body
            case .caption: self = .caption
            case .emphasis: self = .body.weight(.semibold)
            }
        }
    }

    extension Color {
        init(_ color: Mosaic.TextColor) {
            switch color {
            case .primary: self = .primary
            case .secondary: self = .secondary
            case .accent: self = .accentColor
            case .positive: self = .green
            case .warning: self = .orange
            case .negative: self = .red
            }
        }
    }

    extension ContentMode {
        init(_ fit: Mosaic.ImageFit) {
            switch fit {
            case .fit: self = .fit
            case .fill: self = .fill
            }
        }
    }

    extension Mosaic.AspectRatio {
        /// Width to height, or `nil` for the picture's own.
        var ratio: CGFloat? {
            switch self {
            case .original: nil
            case .square: 1
            case .landscape: 4 / 3
            case .wide: 16 / 9
            case .portrait: 3 / 4
            }
        }
    }
#endif
