The reasoning behind `tkg/scripts/sim/CutawayTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cutaway test

Above `const BAR_BUTTON := Rect2(770, 466, 94, 20)`:

```text
THE CUTAWAY'S MOVES, through the cutaway's own handlers, headless:
  godot --headless --path . -- cutawaytest

`CutawayView` moves parts with Run's rule (`lift_part`, `fit_at_mount`,
`stow_at`) and claims loot with the calls SECTOR LOOT makes (`take_item`,
`take_from_jetsam`), so the refit screen, the map's loot popup and the
cutaway cannot disagree. This drives the view's own drop handlers -- what a
real drag ends in -- and checks both the model AND what the view draws (its
hold's icons, its popup's grid), because a model that moved and a screen
that did not is the bug the transfer screen had three times. Then the
picture itself on every hull: see `_check_layouts`.
```

## Layout checks

Above `func _check_layouts() -> void:`:

```text
THE CUTAWAY'S PICTURE, per hull, read off what is DRAWN (`MountPoints`'s
rects, the controls' own rects), not off the layout's own bookkeeping:
 - every word clear of every other word and of the hull's own pixels, every
   lifted part off the hull and off every other part, all of it right of the
   left panel and inside the view;
 - the left panel (the ship's numbers, its hold, DONE) the
   content area's full height, every hold cell and button in it on screen and
   uncovered;
 - the popup (this system's pile) right of the left panel,
   on screen, every cell and button in it too;
 - pointing at a module in each place -- the hold, the hull, this system's
   pile -- shows the MODULES page's own popup for THAT module, clear of the
   left panel, of the thing pointed at and of the open popup, and nothing in
   here carries Godot's own tooltip as well;
 - a bob step carries every part, tag and label with the hull;
 - and the heavy, the biggest ship, drawn at least as big as the medium.
```

## Empty mount words

Above `func _check_empty_words() -> void:`:

```text
EVERY EMPTY MOUNT GETS ITS WORDS (Jon: "There is no text for an empty
utility, just empty systems and empty weapons."). "EMPTY UTILITY" is the
widest of the three and a utility ring sits in the tightest spots, so the
near-ring search found no room and dropped it -- and the check above counted
the rings, never the words. On every startable manufacturer's light, medium
and heavy, in three used states (as launched with a part in the hold, loot in
the system and malfunctions in the deck; one part of each slot taken off; and
crowded, every mount but the last of each slot fitted), carrying a part of
each slot that has an empty mount: one label per empty mount of that slot,
each clear of every part, tag, other label and ring, off the hull's pixels,
inside the view and right of the left panel (its buttons with it); and a
label set away from its ring has a 1 px leader to it that crosses none of
those either.
```

## Swap marks

Above `func _check_swap_marks() -> void:`:

```text
THE SWAP MARKS (Jon: "When you are swapping modules on the ship... can the
swappable modules already installed get highlighted? Just so you know what
can or cannot be swapped with that part."). On three hulls -- Korvan's light,
Solari's medium, Redline's heavy -- each slot's mounts fitted with parts of
different sizes and its last mount left empty, a part of each slot in the
hold and another in this system's pile; once with room in the hold and once
with it packed with crates. For each slot, a part carried from the hold, lifted off
the hull and taken from the pile, through a real drag (`force_drag`, the
viewport's own drag): the mounts the hull marks while it is carried -- fitted
parts framed, empty mounts pinged (`MountPoints.marked`) -- are EXACTLY the
mounts a drop lands on, found by dropping it on every mount of the hull in
turn (at the part's middle or the ring, `_can_drop_data` then `_drop_data` as
the viewport calls them, the cutaway's own handler and Run's rule doing the
rest; the state put back after each). Each drop and a cancel leave nothing
marked; starting
the drag changes no rect of anything drawn or pressed. And a crate carried
marks nothing. Some drop must have been refused on a fitted part of the
carried part's own kind, and some swap marked, or the check proved nothing.
```

## Real LOCAL

Above `func _check_local() -> void:`:

```text
THE REAL LOCAL. A wreck you killed here, your ship, and the screen itself:
 - with the cutaway open, a click where the wreck is drawn opens nothing and
   shuts the cutaway (Jon: "You shouldn't be able to open a wreck when your
   ship is clicked on and in focus");
 - with it shut, the same click opens the wreck's own two-grid screen;
 - in a fight, a click on your ship opens nothing and asks for the thud a dead
   button makes (Jon: "the same thud sound when you try and click on a button
   that doesn't work"), with no outline on it.
```

## Reactor rule

Above `func _check_power() -> void:`:

```text
A module of this slot from the catalogue (of this size, if asked), a copy.
THE REACTOR'S RULE ON A MOUNT (the tutorial audit, Oct 22): a part coming
aboard the reactor cannot carry is refused in the cutaway, as the transfer
screen refuses it (`pad_to_mount`, its hold drop), and the mount is not lit
for it while it is carried. It used to be bolted on past the cap. A part the
reactor can carry, on the same mount, still lands; a fitted part still moves.
```

## The runs routines on the left

Above `func _check_routines() -> void:`:

```text
THE RUN'S ROUTINES ON THE LEFT PANEL (science, plan S8): one line, "ROUTINES
· N OF 9", under the hull's perks, the names on hover (`RoutineBox`). On
Korvan's light, medium and heavy in `_check_layouts`' used state (a part and a
crate in the hold, two malfunctions in the deck), with 0, 1 and all 9 bought,
and the heavy once more with all 9 and twelve malfunctions:
 - with none there is no row (nothing drawn, no hover);
 - with 1 and with 9 the row is inside the panel and on screen, below the
   perks and beside or above the malfunctions, crossing none of the panel's
   other pieces, the panel's contents still fit, and the gaps keep at least
   GAP_MIN + 2 (the heavy with twelve malfunctions and nine routines is the
   fullest panel there is: both lines two digits wide, side by side);
 - its hover names every routine bought and no perk, and the cutaway's own
   card shows nothing over it (one hover).
Then a hull swap (`Run.transfer_to_hull`, Korvan's medium for Solari's
heavy): the same routines listed, the perks changed.
```
