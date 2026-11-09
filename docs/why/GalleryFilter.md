The reasoning behind `tkg/scripts/ui/GalleryFilter.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shared filter

Above `signal changed(state: Dictionary)`:

```text
The filter bar the CARDS and MODULES galleries share.

ONE WIDGET, TWO SCREENS, and the reason is the reason `AttrBlock` is shared:
the two pages answer the same question about different things, and a filter
that drifts between them is a filter a player has to learn twice. It is also
the same set of controls the Yard Manifest carries, so the page a designer
reads and the screen a player reads sort the same way.

Rows are DATA, not layout. A screen hands over a list of {key, label,
options} and gets a bar back; the screen never touches a button. That is what
makes adding a grade or a manufacturer a one-line change in the caller rather than a
row of hand-placed controls here.
```

## Shared options

Above `static func manufacturer_options() -> Array:`:

```text
The two sets both galleries want, built here so they cannot disagree about
the order or the wording. Manufacturer order comes from DB.manufacturers,
which is
the only place it is written down.
A BUTTON IS ONE WORD, and it is the word the manufacturer is CALLED, not the first
token of its legal name. "The Probate Combine" split on spaces gives "The",
which is a button that says nothing and sits next to six that say plenty.

Leading articles are dropped first, which is the only rule needed: every
manufacturer in the game is named <Word> <Word> and one of them wears a "The".
```
