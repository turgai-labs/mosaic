public import Elementary
import Foundation
public import Mosaic

/// The whole document a browser opens: the widget, kept live by the host's stream at `live`, which
/// sends each widget shown after it as an event named ``liveEvent``. Each is morphed into the one
/// there, and animated: a piece with the same path is the same piece in both, and slides from where
/// it was to where it is, by the edges its box lines it up by, its old look fading out where it was
/// if it changed; a new piece fades in, and what's gone fades out.
public struct WidgetDocument: HTMLDocument {
    /// The name of the events the host's stream sends a widget's HTML in.
    public static let liveEvent = "widget"

    let widget: Widget
    let version: Int
    public let title: String
    /// Where the host's stream of widgets is.
    let live: String
    /// Where a press of a button, by its path, on the widget of a version, is posted.
    let press: @Sendable (PiecePath, Int) -> String

    public var lang: String { "en" }

    public init(
        _ widget: Widget, version: Int, title: String, live: String,
        press: @escaping @Sendable (_ path: PiecePath, _ version: Int) -> String
    ) {
        self.widget = widget
        self.version = version
        self.title = title
        self.live = live
        self.press = press
    }

    public var head: some HTML {
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        style { HTMLRaw(Self.css) }
        script(.src("https://unpkg.com/idiomorph@0.7.4/dist/idiomorph.js")) {}
    }

    public var body: some HTML {
        main(.data("live", value: live)) {
            WidgetView(widget, version: version, press: press)
        }
        script { HTMLRaw(Self.liveScript) }
    }

    /// Shows each widget the stream sends, morphed into the one shown, so only what changed changes,
    /// then animated, unless motion is reduced: each thing is measured before the morph and after
    /// it, and goes from the one to the other. A thing with an `id` (`data-anchor`) slides, moved
    /// by the point its box lines it up by, less what the slides around it already move it; any
    /// other thing that moved in its box, or whose own look changed, fades in, unless what it's in
    /// already does; a copy of what's gone, or of a look replaced, fades out where it was. A box's
    /// own look is its kind, not what's in it. A press posts the button's press, read when it's pressed, so it
    /// names the page shown then.
    static let liveScript = """
        const page = document.querySelector('main');
        const still = matchMedia('(prefers-reduced-motion: reduce)');
        const timing = { duration: 220, easing: 'ease-out' };

        const look = (el) =>
          el.tagName === 'IMG' ? el.getAttribute('src') : el.tagName === 'DIV' ? el.className : el.className + '|' + el.textContent;
        const point = (rect, anchor) => {
          const [across, down] = (anchor || 'leading top').split(' ');
          return {
            x: across === 'leading' ? rect.left : across === 'trailing' ? rect.right : rect.left + rect.width / 2,
            y: down === 'top' ? rect.top : down === 'bottom' ? rect.bottom : rect.top + rect.height / 2,
          };
        };
        const fadeIn = (el) => el.animate([{ opacity: 0 }, { opacity: 1 }], timing);
        const fadeOut = (el, rect) => {
          const copy = el.cloneNode(true);
          copy.removeAttribute('id');
          copy.querySelectorAll('[id]').forEach((inner) => inner.removeAttribute('id'));
          Object.assign(copy.style, {
            position: 'absolute', left: rect.left + scrollX + 'px', top: rect.top + scrollY + 'px',
            width: rect.width + 'px', height: rect.height + 'px', margin: '0', boxSizing: 'border-box', pointerEvents: 'none',
          });
          document.body.appendChild(copy);
          copy.animate([{ opacity: 1 }, { opacity: 0 }], timing).finished.then(() => copy.remove());
        };

        function show(html) {
          if (still.matches) { Idiomorph.morph(page, html, { morphStyle: 'innerHTML' }); return; }
          const before = new Map();
          for (const el of page.querySelectorAll('[id]')) {
            before.set(el.id, { rect: el.getBoundingClientRect(), look: look(el), copy: el.cloneNode(true) });
          }
          const added = new Set();
          Idiomorph.morph(page, html, { morphStyle: 'innerHTML', callbacks: {
            afterNodeAdded: (node) => { if (node.nodeType === 1) added.add(node); },
            beforeNodeRemoved: (node) => {
              if (node.nodeType === 1 && before.has(node.id)) fadeOut(node, before.get(node.id).rect);
              return true;
            },
          } });
          // For each thing: how far it moved on the page, how far the slides around it carry it,
          // and whether it, or what it's in, fades in.
          const shifts = new Map(), carries = new Map(), fading = new Set();
          for (const el of page.querySelectorAll('[id]')) {
            let box = el.parentElement;
            while (box && box !== page && !shifts.has(box)) box = box.parentElement;
            const boxShift = shifts.get(box) || { x: 0, y: 0 }, carried = carries.get(box) || { x: 0, y: 0 };
            const inFade = fading.has(box);
            const was = before.get(el.id);
            if (added.has(el) || !was) {
              shifts.set(el, boxShift); carries.set(el, carried);
              if (!inFade) { fadeIn(el); fading.add(el); } else { fading.add(el); }
              continue;
            }
            const anchor = el.dataset.anchor;
            const from = point(was.rect, anchor), to = point(el.getBoundingClientRect(), anchor);
            const shift = { x: from.x - to.x, y: from.y - to.y };
            shifts.set(el, shift);
            const changed = look(el) !== was.look;
            if (anchor) {
              const slide = { x: shift.x - carried.x, y: shift.y - carried.y };
              if (Math.abs(slide.x) > 0.5 || Math.abs(slide.y) > 0.5) {
                el.animate([{ transform: `translate(${slide.x}px, ${slide.y}px)` }, { transform: 'none' }], timing);
              }
              carries.set(el, shift);
              if (changed) { fadeOut(was.copy, was.rect); if (!inFade) fadeIn(el); fading.add(el); }
              else if (inFade) fading.add(el);
            } else {
              carries.set(el, carried);
              const movedInBox = Math.abs(shift.x - boxShift.x) > 0.5 || Math.abs(shift.y - boxShift.y) > 0.5;
              if (inFade) fading.add(el);
              else if (changed || movedInBox) { fadeIn(el); fading.add(el); }
            }
          }
        }

        new EventSource(page.dataset.live).addEventListener('\(liveEvent)', (event) => show(event.data));
        page.addEventListener('click', (event) => {
          const button = event.target.closest('button[data-press]');
          if (button) { fetch(button.dataset.press, { method: 'POST' }); }
        });
        """

    static let css = """
        :root { color-scheme: light dark; --gap: 12px; --line: #c8c8cc; --button: #f2f2f5;
                --secondary: #6e6e73; --accent: #0a66d8; --positive: #1f8a3c; --warning: #b25e00; --negative: #c4271d; }
        @media (prefers-color-scheme: dark) { :root { --line: #48484c; --button: #2c2c30;
                --secondary: #a1a1a6; --accent: #4b9dff; --positive: #4cc56d; --warning: #ffa83d; --negative: #ff6b5e; } }
        body { margin: 0; padding: 24px 16px; font: 16px/1.4 system-ui, sans-serif; }
        p { margin: 0; }
        .stack { display: flex; gap: var(--gap); align-items: center; }
        .stack.vertical { flex-direction: column; }
        .stack.horizontal { flex-direction: row; flex-wrap: wrap; }
        .vertical.leading { align-items: flex-start; } .vertical.trailing { align-items: flex-end; }
        .horizontal.top { align-items: flex-start; } .horizontal.bottom { align-items: flex-end; }
        .grid { display: grid; gap: var(--gap); width: fit-content; max-width: 100%;
                align-items: center; justify-items: center; }
        .list { display: flex; flex-direction: column; gap: var(--gap); align-self: stretch; }
        hr.divider { border: 0; background: var(--line); margin: 0; align-self: stretch; height: 1px; }
        .grid > hr.divider { justify-self: stretch; width: auto; }
        .stack.horizontal > hr.divider { width: 1px; height: auto; }
        .list > * { content-visibility: auto; contain-intrinsic-size: auto 48px; }
        button { font: inherit; padding: 6px 14px; border: 1px solid var(--line); border-radius: 8px;
                 background: var(--button); color: inherit; cursor: pointer; }
        .title { font-size: 1.75em; font-weight: 700; line-height: 1.2; }
        .heading { font-size: 1.25em; font-weight: 600; }
        .caption { font-size: 0.85em; }
        .emphasis { font-weight: 600; font-style: italic; }
        .secondary { color: var(--secondary); }
        .accent { color: var(--accent); }
        .positive { color: var(--positive); }
        .warning { color: var(--warning); }
        .negative { color: var(--negative); }
        img.image { display: block; max-width: 100%; height: auto; border-radius: 8px; }
        img.fit { object-fit: contain; } img.fill { object-fit: cover; }
        button.prominent { background: var(--accent); border-color: var(--accent); color: white; font-weight: 600; }
        button.destructive { color: var(--negative); border-color: var(--negative); }
        input.field { font: inherit; padding: 6px 10px; border: 1px solid var(--line); border-radius: 8px; }
        label.toggle { display: flex; gap: 8px; align-items: center; }
        """
}

/// One widget, as HTML: a row or a column as a box of its pieces, a button posting its press by its
/// path with the version it was shown on, so a press on a widget since replaced can be refused. Each
/// piece's HTML `id` is its path, which the morph keeps it by, and every piece slides from where it
/// was to where it is.
public struct WidgetView: HTML, Sendable {
    let widget: Widget
    let version: Int
    let press: @Sendable (PiecePath, Int) -> String
    /// Where it is: the ids from the widget's top down to it.
    let path: PiecePath
    /// How the box it's in lines it up: the top is a column, centred.
    var anchor = Anchor(horizontal: .center, vertical: .top)

    public init(
        _ widget: Widget, version: Int, press: @escaping @Sendable (_ path: PiecePath, _ version: Int) -> String
    ) {
        self.widget = widget
        self.version = version
        self.press = press
        self.path = PiecePath([widget.id])
    }

    private init(
        _ widget: Widget, version: Int, press: @escaping @Sendable (PiecePath, Int) -> String, path: PiecePath,
        anchor: Anchor
    ) {
        self.widget = widget
        self.version = version
        self.press = press
        self.path = path
        self.anchor = anchor
    }

    public var body: some HTML {
        switch widget {
        case .stack(let stack):
            switch stack.direction {
            case .vertical(let alignment):
                div(
                    .id(Self.name(path)), .class("stack vertical \(alignment.rawValue)"),
                    .style("gap: \(Self.points(stack.spacing.rawValue))")
                ) {
                    children(stack.children, Anchor(horizontal: alignment, vertical: .top))
                }.attributes(contentsOf: anchored())
            case .horizontal(let alignment):
                div(
                    .id(Self.name(path)), .class("stack horizontal \(alignment.rawValue)"),
                    .style("gap: \(Self.points(stack.spacing.rawValue))")
                ) {
                    children(stack.children, Anchor(horizontal: .leading, vertical: alignment))
                }.attributes(contentsOf: anchored())
            }
        case .grid(let grid):
            div(
                .id(Self.name(path)), .class("grid"),
                .style(
                    "grid-template-columns: repeat(\(grid.columns.rawValue), 1fr); gap: \(Self.points(grid.spacing.rawValue))"
                )
            ) {
                ForEach(Array(grid.cells.enumerated())) { index, cell in
                    if let cell {
                        WidgetView(
                            cell, version: version, press: press, path: path.appending(cell.id),
                            anchor: Anchor(horizontal: .center, vertical: .center))
                    } else {
                        // An empty cell holds its place, named by where it is among the cells.
                        div(.id("\(Self.name(path))-empty-\(index)"), .custom(name: "aria-hidden", value: "true")) {}
                    }
                }
            }.attributes(contentsOf: anchored())
        case .list(let list):
            div(.id(Self.name(path)), .class("list")) {
                children(list.items, Anchor(horizontal: .leading, vertical: .top))
            }.attributes(contentsOf: anchored())
        case .divider:
            hr(.id(Self.name(path)), .class("divider")).attributes(contentsOf: anchored())
        case .text(let text):
            p(.id(Self.name(path)), .class("\(text.style.rawValue) \(text.color.rawValue)")) { text.words }
                .attributes(contentsOf: anchored())
        case .image(let image):
            img(
                .id(Self.name(path)), .src(image.address.url.absoluteString), .alt(image.description.rawValue),
                .custom(name: "loading", value: "lazy"),
                .class("image \(image.fit.rawValue)"), .style(Self.imageStyle(image.aspectRatio, image.width?.rawValue))
            ).attributes(contentsOf: anchored())
        case .button(let button):
            Elementary.button(
                .id(Self.name(path)), .class(button.kind.rawValue), .data("press", value: press(path, version))
            ) { button.label.rawValue }.attributes(contentsOf: anchored())
        case .textField(let field):
            input(
                .id(Self.name(path)), .type(.text), .value(field.text), .placeholder(field.placeholder),
                .class("field")
            ).attributes(contentsOf: anchored())
        case .toggle(let toggle):
            label(.id(Self.name(path)), .class("toggle")) {
                input(.type(.checkbox)).attributes(.checked, when: toggle.isOn)
                toggle.label.rawValue
            }.attributes(contentsOf: anchored())
        }
    }

    private func children(_ items: [Widget], _ anchor: Anchor) -> some HTML {
        ForEach(items) { item in
            WidgetView(item, version: version, press: press, path: path.appending(item.id), anchor: anchor)
        }
    }

    /// The edges its box lines it up by, which it slides by from where it was to where it is.
    private func anchored<Tag: HTMLTrait.Attributes.Global>() -> [HTMLAttribute<Tag>] {
        [.data("anchor", value: anchor.classes)]
    }

    /// How a box lines up what's in it, across and down: a vertical stack lines its pieces up across
    /// by its alignment and stacks them from the top; a horizontal one lines them up from the
    /// leading edge, and down by its alignment; a list from the leading edge and the top.
    struct Anchor: Equatable, Sendable {
        let horizontal: HorizontalAlignment
        let vertical: VerticalAlignment

        var classes: String { "\(horizontal.rawValue) \(vertical.rawValue)" }
    }

    /// A path as an HTML id: every character outside a name's own written in hex.
    static func name(_ path: PiecePath) -> String {
        "p-"
            + path.description.unicodeScalars.map { scalar in
                CharacterSet.alphanumerics.contains(scalar) && scalar.isASCII
                    ? String(scalar) : "_\(String(scalar.value, radix: 16))_"
            }.joined()
    }

    /// A picture's shape and width, as CSS has them.
    static func imageStyle(_ aspectRatio: AspectRatio, _ width: Double?) -> String {
        let ratio: String? =
            switch aspectRatio {
            case .original: nil
            case .square: "1 / 1"
            case .landscape: "4 / 3"
            case .wide: "16 / 9"
            case .portrait: "3 / 4"
            }
        return (ratio.map { "aspect-ratio: \($0); " } ?? "") + (width.map { "width: \(points($0)); " } ?? "")
    }

    /// Points as the web writes them: a point is a CSS pixel.
    static func points(_ value: Double) -> String {
        value.rounded() == value ? "\(Int(value))px" : "\(value)px"
    }
}
