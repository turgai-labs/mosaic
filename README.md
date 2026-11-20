# Mosaic

**A widget described once in Swift, built natively everywhere from a few simple pieces.**

A host — a server, an app, a running object — says what a widget is. Every platform builds it
from its own native parts: HTML on the web, SwiftUI on Apple platforms, Compose on Android,
desktop toolkits later. The widget stays live: it changes when the host's state changes, and
what a person does in it goes back to the host.

## The idea

A mosaic is a picture set from small simple tiles. Here the tiles are each platform's native
components, and the picture is the widget. The tiles are few and fixed; the pictures are not.

That one rule keeps it from exploding:

- **Renderers know only the core pieces.** A renderer is small and stays small.
- **Everything richer is composed in Swift,** from core pieces, before it's sent. A card, a
  calendar day, a list row with an icon — written once, on the host, and never in a renderer.

## Two layers

1. **The core: plain Swift values.** A widget is a value built from core pieces, with closures for
   what happens. It runs on any Swift that has enums, closures and `map` — nothing more.
2. **The shell: SwiftUI-like syntax,** added later on top. `VStack { … }` with `if` and `for`
   inside, built with result builders. It produces the same core values, so code written against
   the core keeps working.

The core comes first and has to be good on its own.

## Core pieces

The only things a renderer implements. The list grows rarely, and only by decision.

| Piece | What it is |
|---|---|
| `column`, `row` | Pieces one under another, or side by side, aligned and spaced |
| `text` | Words in a style role |
| `image` | A picture from a URL, with what it shows in words |
| `button` | Something to press, and what pressing it does |
| `textField` | Words to type, and what submitting them does |
| `toggle` | On or off, and what switching it does |
| `choice` | One or several of given options |
| `dateField` | A date, a time, or both |
| `slider` | A number in a range |
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
- **What's being typed isn't overwritten.** An input with focus keeps its text until it loses
  focus or submits.

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
| `event` | renderer → host | A piece's identity and what happened: pressed, switched, submitted, with its value |

What a host writes is a nested Swift value; the flat wire form is Mosaic's own business.

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
- **Forms:** one button submitting several fields at once — a date and a number — needs a typed
  way to read the other fields' values.
- **The shell:** result builders in the Swift that runs host code, before the SwiftUI-like layer.
