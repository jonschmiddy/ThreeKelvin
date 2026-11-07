The reasoning behind `tkg/scripts/ui/ModuleGalleryScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Gallery purpose

Above `const GALLERY_K := ModuleIcon.HOLD_K`:

```text
Every module in the game, on one page.

A development screen, reached with the MODULES tab or `godot --path . -- parts`.
The sibling of CardGalleryScreen and written for the same complaint one level
up: the only way to see a module used to be to find one, which means a wreck
rolling it, which means most of the catalogue is never looked at. A part can
be wrong — wrong shape, wrong slot, wrong manufacturer, a silhouette that reads as
something else — for as long as nobody happens to be handed it.

SHOWS THE PLATE, not a list row. A module's shape is a fact about it now: a
1x3 lance packs differently from a 2x2 bay and reads differently on the hull.
A table of names would hide the one property this page exists to check, so
every part is drawn at the size it occupies in the hold, in a flow that lets
the shapes sit against each other.

Grouped by manufacturer, manufacturers first and the unbranded last — the same order
and the same reason as the card gallery: a manufacturer's mark only works if it does
not look like the other six, and that is a comparison you can only make with
them side by side.
```

## Plate scale

Above `const GALLERY_K := ModuleIcon.HOLD_K`:

```text
How big a plate is drawn HERE. THE SAME 2x the hold and the refit hull are
authored at, which it was not: this page asked for a 3x box and got a 2x
sprite inside it, because `ModuleIcon._draw` passed HOLD_K and never this.
The gap between the two was the border. Closing it downward rather than
upward is deliberate -- a catalogue at 3x was bigger than the screen you
actually handle parts on, which made the same module read as two sizes.
```

Inside `_fill()`, above `icon.custom_minimum_size = ModuleIcon.footprint_box(m2, GALLERY_K)`:

```text
THE SAME 2x AS THE HOLD, and the box and the body are now told the
same number so they cannot drift apart again.

The hold and the refit hull are both authored at 2x and the sector
drops to 1x. footprint_box and MountPoints.part_rect share their
arithmetic so a part is the SAME size wherever you actually handle
it — that property is what made an earlier 1x version wrong here,
and a later 3x version wrong in the other direction.

The 3x came with a reason — "large enough to read a silhouette at a
glance" — that only held while every part WAS a silhouette. Real
sprites read at the size they were drawn for, and blowing a 40x20
gun up past that shows its pixels rather than its shape.

custom_minimum_size and NOT size: a flow container decides where its
children go, and asking for a size it did not choose is how the hold
once drew 1x1 plates at 44px.
```

## Column reference

Inside `_build()`, above `_col = col`:

```text
KEPT, because every press of the filter refills this exact column. It was
lost once: deleting the readout panel took a slice that ran up to the
_fill call and swallowed the line above it, so _col stayed null, Widgets
.clear(null) threw on every press, and the page silently kept whatever the
first build had put there. The buttons lit up and nothing moved.
```

## Rebuild on press

Above `func _fill(col: VBoxContainer) -> int:`:

```text
GROUPED BY MANUFACTURER OR BY SIZE, and filtered, from the bar above.

The whole list is rebuilt on every press rather than hiding children. It is
seventy-seven plates and a flow container that has to reflow anyway, and the
alternative — keeping every icon alive and toggling visibility — means the
group headings have to know how many of their own children are still showing.
That bookkeeping is what a rebuild is for.
```

## Shape rows

Inside `_fill()`, above `var flow: HFlowContainer = null`:

```text
ONE ROW PER SHAPE, labelled. The parts are already sorted by shape, so
this walks them and starts a new row wherever the footprint changes —
which means the subsections cannot disagree with the sort, because they
ARE the sort made visible.

A single flow was the version before: correct order, but a 1x1 and a 2x2
ran together on one line and the eye had to find the size change itself.
```

## Hover lift

Inside `_fill()`, above `icon.mouse_entered.connect(func() -> void:`:

```text
THE SAME TICK THE HOLD AND THE HULL MAKE, and a lift with it. A
page of parts you can point at should answer the pointer the way
every other one does -- the installed rows slide left under it, so
these rise.

`position`, not a container property: an HFlowContainer decides
where its children go and rewrites anything it owns on the next
sort, but it leaves an offset applied AFTER that alone. Two pixels,
because the plates are drawn at 2x and one game pixel is the
smallest move that is a move.
```

Above `const LIFT_PX := 2.0`:

```text
UP TWO PIXELS AND BACK, on a tween rather than a jump.

SHORT, because a hover is not an event -- 0.09 s is long enough to read as a
movement and short enough that running the pointer along a row does not leave
a wave behind it. Killed on re-entry so a fast sweep cannot stack tweens on
one plate.
```

## Shape sort

Above `func _by_size(parts: Array) -> void:`:

```text
BY SHAPE: 1x1, 2x1, 3x1, 4x1, then 2x2.

Height first, then width. That puts every one-deep part in a clean
progression of lengths and leaves the block on its own at the end, which is
how somebody describes the catalogue out loud — the ones, the twos, the
threes, the long ones, and the square.

Sorting by CELLS first was the version before this, and it interleaved the
thing the eye is following: a 4x1 and a 2x2 are both four cells, so a row of
lengthening bars had a square dropped into the middle of it.

Before either, a manufacturer block came out in DATABASE order — the order somebody
typed the parts in — so a 2x2 bay sat between two 1x1 sights and the row read
as noise.
```

Inside `_by_size()`, above `if a.rarity != b.rarity:`:

```text
THEN BY GRADE, left to right, common through contraband. Inside one
shape row every plate is the same rectangle, so the only thing left to
read is the ground it is painted on — and a row that climbs makes the
grade ladder a thing you can see rather than a thing you look up.

It was alphabetical, which orders eleven identical 2x1 plates by a word
that is not written anywhere on them.
```
