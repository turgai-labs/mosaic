# Mosaic

Server-driven UI widgets for Swift.

- The host builds a widget tree from its state. A widget is a value: a tree of a small fixed set
  of pieces.
- Each platform renders the tree with native components: HTML, SwiftUI, Compose.
- After each state change the host builds the tree again, diffs it against the previous one by
  identity, and sends a patch.
- Events from the renderer (a press, a field change) go back to the host, which runs the handler
  attached to that piece.
- Renderers implement only the core pieces. Larger widgets are composed from them on the host,
  so adding one needs no renderer change.

## Status

- **Built:** `Widget` (`row`, `column`, `text`, `button`, `image`), `Widget.checked()`, and
  `MosaicHTML` — server-rendered HTML, updated over server-sent events with a keyed DOM morph
  (idiomorph). Buttons are identified by their label.
- **Designed, not built:** closure handlers, fields, `list`, the patch protocol, the SwiftUI
  renderer.

## Two layers

1. **The core: plain Swift values.** A widget is a value built from core pieces, with closures for
   what happens. It runs on any Swift that has enums, closures and `map` — nothing more.
2. **The shell: SwiftUI-like syntax,** added later on top. `VStack { … }` with `if` and `for`
   inside, built with result builders. It produces the same core values, so code written against
   the core keeps working.

## Core pieces

The only things a renderer implements. The list grows rarely, and only by decision.

| Piece | What it is |
|---|---|
| `column`, `row` | Pieces one under another, or side by side, aligned and spaced |
| `text` | Words in a style role |
| `image` | A picture from a URL, with what it shows in words |
| `button` | Something to press, and what pressing it does |
| `textField` | Words to type, and what happens as they change |
| `toggle` | On or off, and what happens as it changes |
| `choice` | One or several of given options, and what happens as they change |
| `dateField` | A date, a time, or both, and what happens as it changes |
| `slider` | A number in a range, and what happens as it changes |
| `list` | Rows, each with an `id` |
| `divider` | A line between pieces |

## A widget is computed from state

There are no bindings. A widget is a value the host computes from its state, as Elm and Phoenix
LiveView render:

```swift
var today: Widget {
    .column([
        .text("Cycle day \(cycleDay)", style: .title),
        .toggle("Daily reminder", isOn: reminderOn) { on in self.setReminder(on: on) },
        .list(diary.map { entry in
            .row(id: entry.date, [
                .text(entry.sensations.joined(separator: ", ")),
                .button("Remove", kind: .destructive) { self.removePain(date: entry.date) },
            ])
        }),
    ])
}
```

- **What happens is a closure,** next to the piece it belongs to. It's ordinary Swift, checked as
  Swift: no action names, no labels to match, no handler that sorts presses out.
- **A row's closures close over the row's own values,** so a button knows which item it's in.
- **Closures stay with the host.** Only identities travel. A press names a piece; the host finds
  it in the current widget and runs its closure, as a message to itself.
- **After every change the host computes the widget again,** compares it with the last one by
  identity, and sends only what differs.
- The host's state changes only through its own code — the widget never writes it.

## Fields

A field shows its own value at once, as a native field does, and tells the host as it changes.
Each change says whether it's still being made or finished:

```swift
.textField("What do you feel?", text: note) { change in
    switch change {
    case .editing(let text): self.note = text
    case .submitted(let text):
        self.logPain(text)
        self.note = ""
    }
}
```

- **The host decides what a change means:** ignore it, keep it, or react to it as it's typed.
- **A form is fields the host keeps current,** and a button that reads them:
  `.button("Start") { self.start(firstDay: self.day, length: self.length) }`.
- **Edits are throttled.** A renderer sends `editing` at most every few hundred milliseconds, and
  once more when the field loses focus — never every keystroke.
- **A press comes after the edits before it.** A renderer sends a field's last change before any
  press that follows, in order, so a button never reads a value older than what's on screen.
- **The echo doesn't fight the typing.** While a field is being edited it keeps its own value and
  ignores what the host sends for it. After `submitted`, or once it loses focus, it takes the
  host's value again — which is how a host clears a field.
- **A host that keeps its state durably** should keep `editing` changes only when it needs them,
  so typing doesn't become a stream of writes.

`toggle`, `choice`, `dateField` and `slider` change in one step, so their changes are always
finished.

## Composites

A composite is a Swift function or value that builds a widget from core pieces — a row with an
icon, a day in a calendar. It's computed on the host, so renderers never see it, and libraries of
composites grow without touching any renderer.

## Updates

A renderer changes only what changed, by identity, as SwiftUI and Phoenix LiveView do.

- **Every piece has an identity:** its `id` when it has one, or else its place — its parent's
  identity and its index. Every row of a `list` has an `id`, unique among its rows.
- **The new widget is matched to the old by identity:** the same identity is updated in place, a
  new one is made, a missing one is removed, a row whose place changed is moved.
- **What's being typed isn't overwritten.** A field being edited keeps its own value until it's
  submitted or loses focus.

SwiftUI and Compose do this themselves, given stable ids. On the web the renderer does it with a
keyed morph of the DOM.

## Style

Only roles, never pixels or colors: `title`, `heading`, `body`, `caption` for text; `normal`,
`prominent`, `destructive` for buttons; `primary`, `secondary`, `accent`, `positive`, `warning`,
`negative` for tone. Each platform maps them to its own native look.

## On the wire

| Message | Direction | Carries |
|---|---|---|
| `widget` | host → renderer | The core pieces, flattened, each with its identity — whole the first time |
| `patch` | host → renderer | What changed since, by identity |
| `event` | renderer → host | A piece's identity and what happened: pressed, or changed — editing or finished — with its value |

Hosts build nested values; the wire form is flat.

## Renderers

| Platform | Built with | When |
|---|---|---|
| Web | HTML from Elementary, live over server-sent events | First |
| iOS, macOS | SwiftUI | First |
| Android | Compose, or SwiftUI through Skip | Next |
| Linux, Windows | To be chosen | Later |

## Not goals

- Drawing pixels, custom graphics, animation choreography.
- Logic in the renderer. A renderer shows and reports what happened — it never decides.
- Matching any existing format. Mosaic's pieces are its own.

## Open questions

- **Written by models.** Hosts may let a model write widgets as Swift values. The core types
  must stay simple enough for a small model, and expressible as a generated schema, where
  recursive types are a problem today.
- **Images:** URLs only, or also data the host holds.
- **More than one screen:** whether a widget can lead to another, or a host shows one at a time.
- **The shell:** result builders in the Swift that runs host code, before the SwiftUI-like layer.
