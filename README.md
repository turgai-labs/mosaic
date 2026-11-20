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

## Core pieces

The only things a renderer implements. The list grows rarely, and only by decision.

| Piece | What it is |
|---|---|
| `Stack` | Pieces in a row or a column, aligned, spaced |
| `Text` | Words in a style role |
| `Image` | A picture from a URL, with what it shows in words |
| `Button` | Something to press, which sends an action |
| `TextField` | Words to type |
| `Toggle` | On or off |
| `Choice` | One or several of given options |
| `DateField` | A date, a time, or both |
| `Slider` | A number in a range |
| `List` | One piece repeated for each item of a collection in the state |
| `Divider` | A line between pieces |

## Composites

A composite is a Swift value that builds itself from core pieces. It's expanded on the host, so
renderers never see it. Libraries of composites can grow freely — renderers don't change.

## State, apart from layout

- The host's **state** is data. Pieces **bind** to it by path: a `Text` shows `/forecast/today`,
  a `Toggle` holds `/reminder/on`, a `List` repeats over `/diary`.
- When the state changes, only the **values** travel. The layout stays where it is.
- The layout changes only when the host's widget itself changes.

## Actions

- Pressing a `Button` sends an **action**: its name, and the current values of the inputs it
  names.
- Inputs edit locally. The host's state changes only by an action — the host decides, the widget
  never writes the state itself.

## Updates

A renderer changes only what changed, by identity, as SwiftUI and Phoenix LiveView do.

- **Values change** — the common case. A renderer knows which nodes each path is bound to, and a
  `values` patch sets exactly those. The layout, focus and scroll stay untouched.
- **A collection changes.** Each item of a `List` has a key, `id` unless said otherwise. A renderer
  keeps one node per key: new keys are inserted, gone ones removed, moved ones moved. Unchanged
  items keep their nodes, and any input in them keeps its text.
- **The layout changes.** Every piece has an identity: its `id` when it has one, or else its place —
  its parent's identity and its index. The new layout is matched to the old by identity: the same
  identity is updated in place, a new one is made, a missing one is removed.
- **What's being typed isn't overwritten.** An input with focus ignores incoming values until it
  loses focus or its action is sent.

SwiftUI and Compose do this themselves, given observable state and stable ids. On the web the
renderer does it: bound nodes and list keys by hand, and a keyed morph of the DOM for a new layout.

## Style

Only roles, never pixels or colors: `title`, `heading`, `body`, `caption` for text; `normal`,
`prominent`, `destructive` for buttons; `primary`, `secondary`, `accent`, `positive`, `warning`,
`negative` for tone. Each platform maps them to its own native look.

## On the wire

Three messages, versioned:

| Message | Direction | Carries |
|---|---|---|
| `layout` | host → renderer | The widget's core pieces, flattened, each with an id |
| `values` | host → renderer | The state its pieces bind to, whole or as a patch |
| `action` | renderer → host | An action's name and its inputs' values |

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
- Logic in the renderer. A renderer shows, binds and sends — it never decides.
- Matching any existing format. Mosaic's pieces are its own.

## Open questions

- **Written by models.** Hosts may let a model write widgets as Swift values. The core types
  must stay simple enough for a small model, and expressible as a generated schema, where
  recursive types are a problem today.
- **Images:** URLs only, or also data the host holds.
- **More than one screen:** whether a widget can lead to another, or a host shows one at a time.
- **Lists:** how much a `List` item may hold before it's a composite of its own.
