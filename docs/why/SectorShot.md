The reasoning behind `tkg/scripts/sim/SectorShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sector shot

Above `func _snap(tree: SceneTree, path: String) -> void:`:

```text
The arrival screen, photographed:
  godot --path . -- sectorshot [seed=N] [group]

NEEDS A WINDOW. Under `--headless` the dummy display server never emits
`frame_post_draw`, so nothing is captured and it looks exactly like a hang.

IT EXISTS BECAUSE 8b IS A LAYOUT. `ENCOUNTER_FLOW.md` beat 2 is a drawing of a
screen -- a group box, a check badge, a row per option -- and none of that is
something an assert can look at. The list either reads or it does not.

`group` hunts for a system carrying an EXCLUSIVE set, because that is the half
of the design with no fallback: an independent option is one row and a group is
the whole of rulings 1 and 1b. Without one on screen the shot proves the easy
case.
```

## Spent system

Inside `run()`, above `if "spent" in OS.get_cmdline_user_args():`:

```text
A SYSTEM WITH NOTHING LEFT IN IT, which is a fourth drawer state and the
only one no mode could reach. `open=` and `take=` walk LIST -> OPTION ->
RESULT, and all three of those need a system that still has options; the
band that a FINISHED system gets is the one thing they cannot photograph.
Marking the claims directly rather than resolving each option: what is
being looked at is the height of a drawer with an empty list, and running
four payouts to get there would put their loot in the picture.
```

## Hover shot

Inside `run()`, above `if "hover" in OS.get_cmdline_user_args():`:

```text
WHAT AN EXCLUSIVE SET LOOKS LIKE WHEN YOU POINT AT ONE OF IT. RULING 1 is
a hover now rather than a box, so there is no frame in which it is visible
by itself -- and `Input.parse_input_event` plus `warp_mouse` does not drive
GUI in a window that does not have focus, which has produced false failures
here before. Notifying the card is what a pointer over it would do, and it
is the same "drive the screen directly" the open= and take= modes use.
```

## Drawer states

Inside `run()`, above `if "region" in OS.get_cmdline_user_args():`:

```text
THE DRAWER HAS THREE STATES AND A SCREENSHOT ONLY EVER CATCHES THE FIRST.
`open=N` clicks into an option, `take=N` resolves one of its choices, so
LIST -> OPTION -> RESULT can each be photographed. Driving the screen
directly rather than faking a pointer, for the same reason the hover shot
does: there is no pointer.
`combat` swaps the drawer for the hand, which is the only way to see
whether the two bands actually match -- they are mutually exclusive, so no
single frame shows both and the comparison is between two screenshots.
`menu` proves the view memory does not leak into the launcher's galaxy.
It pans the starchart's remembered view a long way off centre, opens the
menu, and reports where the menu's own chart actually ended up -- which is
the bug: both screens build the same MapChart, and the memory is on the
class rather than on the instance.
`region` proves what LOCAL REGION does to an arrival. ON, the chart must
re-frame on where you are standing; OFF, it must come back exactly where
you left it. Both are one flag and one code path, so one of them silently
doing the other's job is the failure to watch for.
```

## Glide sampling

Inside `run()`, above `for iA in 3:`:

```text
THREE FRAMES, NOT THIRTY. A glide runs 0.55s -- about thirty-three
frames -- so sampling at thirty reads almost the end state and
cannot tell a snap from an animation nearly finished. If the view
is already final here, nothing tweened.
```

Inside `run()`, above `for i8 in 6:`:

```text
SAMPLED EARLY AND LATE, and the early sample is the one that matters.
The last time an animation was checked here it was sampled at 30 frames
against a run of 33, which cannot tell a glide from a snap. Six frames
is a tenth of the way through half a second, so a ship that is NOT
animating reads as zero here and fails loudly.
```

## Photograph only

Inside `run()`, above `var n0: MapGen.MapNode = Run.node_at()`:

```text
A PHOTOGRAPH, and nothing else. This mode had grown eight probes
chasing a bug that turned out to be a signal with no listener, and
every one of them asserted on the model -- the half that was never
broken. `-- transfertest` now does that properly and headlessly, on
what is DRAWN, so what is left here is the job a shot is actually for.
```

## Ghost number

Inside `run()`, above `for hv in sl._hand.get_children():`:

```text
THE GHOST'S NUMBER, checked where it can honestly be checked.

NOT END TO END, and the reason is worth writing down. The ghost is
built inside `CardView._get_drag_data` and handed to
`set_drag_preview`, which only parents it during a drag the ENGINE
started. Calling `_get_drag_data` directly returns the payload but
throws the preview away, so a search of the tree reports NOT FOUND
on a fix that works. Driving a real drag with pushed events was
tried next and `gui_is_dragging()` stayed false even with the
coordinates through `get_final_transform` and the card confirmed
playable -- `FitTest` warns about this exact ground, and drives
only the pick-up for the same reason.

So this checks the property the fix is: that a `CardView` handed a
live figure BEFORE `setup` prints it, which is the order
`_get_drag_data` now uses. The drag itself is checked by hand.
```

## Readout placement

Inside `run()`, above `print("  your name y %.0f ; their name y %.0f"`:

```text
WHERE THE TWO READOUTS ACTUALLY LAND, which is a question two
different rules answer. Yours hangs `PLATE_AIR` below the
sprite's last opaque row, so it tracks YOUR hull. Theirs is
simply the next child after a fixed 240x120 art box, so the
contact's size does not move it at all -- measured across
cutter, hulk, whale and leviathan it spans four pixels, while
yours does not move.

RULED: leave them on their own rules. The gap is a steady four
to six pixels and yours hugging your ship is what makes it read
as belonging to the ship. Swapping YOUR hull is the case that
would separate them, and that is the case to judge it on.
```

## Drift sampling

Inside `run()`, above `for ih in 240:`:

```text
240 FRAMES, BECAUSE THE CYCLE IS FOUR SECONDS. Sampled over 40
the ship sat at the top of its arc the whole time and the range
came out 2..2 -- a still ship and a slow one are the same
reading through too short a window.
```

## Discard pile

Inside `run()`, above `var seed_from: Array = sp.combat.deck.duplicate()`:

```text
THE DISCARD, because it is the pile that is empty when a fight
opens and so the one whose listing is easy to get wrong. Fed from
the draw pile so the cards are real ones.
NINETEEN, so the flow WRAPS and the scroll has something to
scroll. A one-card discard is the case that cannot fail: it
fits on any row, at any column count, with or without the
ScrollContainer working at all.
```

## Card positions

Inside `run()`, above `print("    card base_y %.0f (rest y %.0f)"`:

```text
WHERE THE CARDS ACTUALLY SIT. The hand stretches to the row and the
cards are placed against a baseline inside it, so the gap above and
below them is not any constant in the file -- it has to be read.
WHERE A HOVER WOULD SPRING BACK TO. It is captured in `_ready`,
which fires before the hand positions the card, so it was always
zero -- and a hovered card animated to the top of the band rather
than back to its own row.
```

Inside `run()`, above `var sv: Control = sc._view.ship_view()`:

```text
WHERE A HOVERED CARD'S TOP EDGE IS, against where the rails start.
The lift is -8 from the resting baseline, so this is the line the
ENERGY and END TURN boxes are meant to square up to.
WHERE THE SHIP ACTUALLY IS, against where the plate went. The art
Control is not the slot -- it sizes and animates itself -- so the
offset from its rect centre is a number to read, not to reason to.
```
