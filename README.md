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

- **Built:** the pieces as `Identifiable` structs — `Column`, `Row`, `Text`, `Image`, `Button`,
  `TextField`, `Toggle` — with `Widget` as their sum; every piece has an id, its own among its
  siblings, and a `PiecePath` from the top; `Widget.checked()`; `Event`. `MosaicHTML` renders a
  widget as HTML, live over server-sent events with a keyed DOM morph; a press names its button by
  path.
- **Not built yet:** events from text fields and toggles, closure handlers, `list` and the other
  inputs, the session rules, the SwiftUI renderer.

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
- **After every change the host computes the widget again,** and sends a patch against the last
  one.
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
- **A host that keeps its state durably** should keep `editing` changes only when it needs them,
  so typing doesn't become a stream of writes.

`toggle`, `choice`, `dateField` and `slider` change in one step, so their changes are always
finished. How changes travel — throttled, in order, never over what's being typed — is under
Events.

## Composites

A composite is a Swift function or value that builds a widget from core pieces — a row with an
icon, a day in a calendar. It's computed on the host, so renderers never see it, and libraries of
composites grow without touching any renderer.

## Identity

Rules from SwiftUI. A piece's identity is how a renderer knows it's the same piece from one widget
to the next.

- **Explicit:** its `id`, when it has one.
- **Structural:** otherwise, its kind and its place — the parent's identity, its index, and
  whether it's a `text`, a `button`, a `row`. A place whose kind changes holds a new piece.
- **What a piece holds lives as long as its identity:** a field's typed text and focus, a list's
  scroll position. When the identity ends, they end. To start a piece fresh, give it a new `id`.
- **List rows have explicit ids, stable and unique:** a row's own key, never its index or a random
  value. An index would tie a row's held state to a position; a random id would recreate every
  row on every change. Two rows with one id are refused.
- A host that wants a piece to stay the same across two states keeps the same kind at the same
  place, or gives both the same `id`, and changes only its values.

## Patches

The first message is the whole widget. Every one after it is a patch against the widget the
renderer has: only what changed, by identity. The list rules are LiveView's.

- **A piece whose values changed** is sent with just those values.
- **A piece whose kind changed, or a new piece,** is sent whole.
- **A piece that's gone** is named, and removed.
- **An unchanged piece** isn't sent.
- **A list** is sent as its count and the rows that differ, by position:
  - an unchanged row in the same position — nothing;
  - an unchanged row that moved — the position it came from;
  - a changed row — its patch, with the position it came from if it moved;
  - a new row — whole.

A renderer applies a patch to the widget it has, then updates its native views by identity.

## Events

- **Every event has a number,** counted by the renderer. Every patch says the last event the host
  had handled when it was made, and the host answers every event with a patch — an empty one when
  nothing changed.
- **A piece waits for its event.** After a press, the button ignores further presses until a
  patch acknowledges that event — a double tap isn't two actions. A renderer may show it as busy.
- **A field being edited is never overwritten.** It keeps its own value until it's submitted or
  loses focus, whatever patches arrive; then it takes the host's value.
- **Edits are throttled,** at most every few hundred milliseconds, and sent once more on losing
  focus. A press is sent after the edits before it, in order.
- **An event for a piece that's gone is dropped** by the host: the piece it named no longer exists.
- **After a reconnect** the host sends the whole widget again, and the renderer sends the last
  edit of any field still being edited, so typed text isn't lost.

SwiftUI and Compose redraw by identity themselves, given stable ids. On the web the renderer does
it with a keyed morph of the DOM.

## Style

Only roles, never pixels or colors: `title`, `heading`, `body`, `caption` for text; `normal`,
`prominent`, `destructive` for buttons; `primary`, `secondary`, `accent`, `positive`, `warning`,
`negative` for tone. Each platform maps them to its own native look.

## On the wire

| Message | Direction | Carries |
|---|---|---|
| `widget` | host → renderer | The whole widget, flattened, each piece with its identity |
| `patch` | host → renderer | What changed, by identity, and the last event handled |
| `event` | renderer → host | Its number, a piece's identity, and what happened: pressed, or changed — editing or finished — with its value |

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
