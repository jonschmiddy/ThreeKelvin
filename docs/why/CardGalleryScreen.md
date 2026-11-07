The reasoning behind `tkg/scripts/ui/CardGalleryScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Gallery purpose

Above `const LIFT := 18.0`:

```text
Every card in the game, on one page.

A development screen, reached with the CARDS tab or `godot --path . -- cards`.
Card work is the most iterated thing in this project and the only way to see a
card used to be to draw it in a fight — which shows you five, chosen by the
shuffle, from whatever you happen to have installed. Half the catalog could be
wrong for a week and nothing would say so.

Grouped by manufacturer, because the banner, the emblem and the cut are the
one part of a card that is meaningless in isolation — a manufacturer's mark only
works if it does not look like the other six.

Hovering lifts the card off the grid and opens a readout beside it. It is a
LIFT and not a zoom: there are exactly two card scales, frozen an octave
apart, because anything between them puts the frame on half-pixels and softens
the 8px font. "Slightly bigger" is not a size this game has, and doubling — the
only other integer option — swallows a third of the screen.

The lifted copy floats in an overlay rather than the real card moving, because
moving it means a child of a flow container changing position, and the
container answers by reflowing the entire catalog under your cursor.
```

## Copies collapsed

Inside `_build()`, above `{key = &"dupes", label = "Copies", options = [`:

```text
COLLAPSED BY DEFAULT, which is a change of what this page means and is
therefore worth saying out loud. It used to answer "what does the deck
get", so a module that authors one verb and grants two showed its card
twice, side by side -- KM-4 grants Charged Slug twice, and Feed and
Bolt On are shared cards several modules hand out. All correct, and all
noise when the question is "what art still needs drawing".
`All copies` puts the old view back.
```

## Rebuild on press

Above `func _fill(col: VBoxContainer) -> int:`:

```text
GROUPED BY MANUFACTURER OR BY GRADE, and filtered, from the bar above.

Manufacturers first and the unbranded last: precursor and grown things have no
banner to compare, so they are not part of the comparison the grouping exists
to make.

Rebuilt on every press rather than hiding children, for the same reason the
module gallery is: the group headings carry counts, and a heading that has to
know how many of its own children are still visible is bookkeeping a rebuild
does for free.
```

## Card manufacturer

Inside `_fill()`, above `if manufacturer == &"(unbranded)":`:

```text
THE CARD'S OWN MANUFACTURER, not its part's (Jon, Oct 18): a shared card a
Korvan part grants is drawn unbranded, so it files under UNBRANDED
and never under KORVAN.
```

## Malfunctions

Inside `_fill()`, above `var faults: Array = []`:

```text
MALFUNCTIONS, which no module grants and which therefore never appeared on
this page at all. Sixteen of the seventy-six illustrations the game owes
are malfunctions, and the one dev screen that shows many cards at once
could not show any of them -- which is how a rendering bug that blanked
every malfunction art window survived being looked at.

Shown only when no manufacturer or slot filter is set, because they answer
neither question: a malfunction has no manufacturer and fits no slot. They carry
`part = null` for the same reason, and nothing downstream reads `part`.
```

## Lift not zoom

Inside `_on_hover()`, above `var rest := v.global_position - global_position`:

```text
A LIFT, not a zoom.

There are exactly two card scales and they are frozen an octave apart —
1x and 2x — because anything between them puts the frame on half-pixels
and softens the 8px font, which is the one thing the frozen sizes exist to
prevent. So "slightly bigger" is not a size this game has. Doubling was
the only other integer option and it swallowed a third of the screen.

The feel comes from the card rising off the grid instead: same size, six
pixels up, an ember frame around it, and the readout opening to the right.
That is what the hand does when you hover a card, and it costs no
resolution at all.
```

## Readout clamp

Inside `_on_hover()`, above `await get_tree().process_frame`:

```text
Only now can it be kept on screen.

The panel's height is not a number this function knows: every label in it
wraps, so how tall it ends up depends on how much text wrapped, and that
is settled by the layout pass rather than by the code that builds it. The
previous clamp used a flat 200px guess, which was fine for a two-keyword
card and ran off the bottom of the screen for anything wordier.

One frame later the real height exists. The fade covers the correction,
and is_instance_valid covers the case where the cursor has already moved
on and taken this panel with it.
```
