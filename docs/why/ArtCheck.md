The reasoning behind `tkg/scripts/sim/ArtCheck.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Coverage gate

Above `const MANUFACTURERS: Array[StringName] = [&"korvan", &"", &"solari"]`:

```text
What still has no art, and what has art of the wrong size:
  godot --headless --path . -- artcheck

THE COVERAGE GATE for the module and card art batch. Scope is Korvan,
unbranded and the malfunctions — 43 modules and 76 cards — and everything
else is deliberately out, so a manufacturer that has not been drawn yet does
not read as a hundred failures.

IT PASSES WITH EVERYTHING MISSING, and that is the point. A module without a
sprite draws its silhouette and a card without an illustration draws its
glyph; both are the designed fallback rather than a fault, so missing art is
COUNTED and listed, never failed on. What fails is art that exists and is
wrong — the wrong size for the box it has to sit in, which is the one mistake
that cannot be seen from a filename and is invisible on screen until you know
what you are looking for.

THE BOX IS A GUIDE, NOT A FRAME, so this does not demand an exact size. A
sprite is generated at the width its cells ask for and cropped to its own ink
-- nothing is resampled -- so its height is whatever the art needed. A gun
standing a row or two proud of its mount is a gun. What is checked is that it
does not miss by a WIDE margin: far over and it hangs off the hull, far under
and there is nothing to see at fifteen pixels.

The size a module wants is arithmetic, not a constant: MountPoints sizes a
fitted part from the hold's cell at half scale, so it is derived here from
the same numbers rather than written down twice.
```

## Card art width

Above `const CARD_ART := Vector2i(92, 60)`:

```text
CARD ART IS 92 WIDE AND THE WINDOW IS 93, and that one pixel is not a bug.
`create_image_pixflux` refuses an odd side at this size -- it answers 93x60
with "Use 92x60 instead" -- so the art is generated one column short and
centred, which leaves half a pixel of margin against a window that is already
a recessed dark box. Height is exact.
```

## Card dump

Inside `run()`, above `if "cards" in OS.get_cmdline_user_args():`:

```text
`-- artcheck cards` dumps every illustration owed, one per line, with what
the card IS. Writing seventy-one prompts off the card gallery means reading
them off a screen one at a time; this is the same list as a file.

TAB SEPARATED, because the consumer is a script. `glyph_kind` is in it
because it is the game's OWN answer to "what does this card look like" --
the procedural art has been sorting cards into slug, burst, charge, pyre,
brace and the rest all along, and a prompt that ignores that is inventing a
second taxonomy for the same objects.
```

Inside `run()`, above `print("%s	%s	%s	%s	%s	%s	%s	%s	%s	%s" % [`:

```text
`describe()` and the type line are in it because a DESIGN SHEET is
written off this file, not off the card gallery, and a brief for a
picture that does not know what the card does is how four cards
ended up asking for the same muzzle flash. `type` and `glyph` are
both here on purpose: they are the game's two existing answers to
"what is this", and where they agree across many cards is exactly
where the illustrations are about to collide.
```

## Shop rooms

Above `func _shop_rooms() -> Dictionary:`:

```text
THE SHOP ROOMS AS INSTALLED. Jon's fifteen rooms are data -- `rooms.json`
and the pictures beside it, written by `tools/room_install.py` -- and the
mistakes that data invites are the silent ones: a picture the game cannot
load draws nothing, a light file of the wrong size lights nothing, a level
with no room gets a shop with no walls. Each is counted here as a fault,
because unlike a module with no sprite there is no designed fallback.
```

## Hold judging

Inside `_room_faults()`, above `if key == "hold":`:

```text
A HOLD IS JUDGED BY WHAT IS DRAWN, at each of its sizes: the frame's
painted pixels, and the grid standing in its opening. Its box is the
heavy frame's picture, clear margins and all, and Jon hangs his with
those margins past the wall's edge -- four of his five Exchanges,
every painted pixel inside (2026-09-27).
```

## Drawn families

Above `const ENEMY_CANVAS := Vector2i(EnemyArt.W, EnemyArt.H)`:

```text
---------------- the three families that are still drawn ----------------

Same philosophy as the two above and it is worth restating, because these
three start at zero: MISSING IS NOT A FAILURE. Every one of them has a
procedural drawing behind it that is the designed fallback, so what is
counted is coverage and what is FAILED is a file that exists and is the wrong
size -- the one mistake that cannot be seen from a filename.

THIS IS ALSO THE SEAM'S OWN GATE. The screens these appear on are not
reproducible frame to frame -- the station strobes, the beacon's rings and the
enemy bob all move on wall-clock time, and two runs of identical code differ
by tens of thousands of pixels -- so "the picture did not change" cannot be
tested by comparing shots. What CAN be tested is that with no files on disk
every loader answers null and every drawing site therefore takes the path it
always took. That is what the counts below are for.
```

## Module box

Above `func _module_box(m: ModuleData) -> Vector2:`:

```text
THE BOX A FITTED PART OCCUPIES, in art pixels, at the refit screen's own
scale. Derived from the same three numbers MountPoints.part_rect uses, so
retuning the hold cannot leave this check vouching for the old size.

`k` is 1 because that is what ShipScreen passes to magnify() unzoomed, and
the unzoomed view is the one the asset has to be authored for — the zoom then
draws the same file at a whole 2.
```
