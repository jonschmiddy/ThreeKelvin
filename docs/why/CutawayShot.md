The reasoning behind `tkg/scripts/sim/CutawayShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shot purpose

Above `const PROC: Array[StringName] = [&"heliostat", &"plasma", &"sunheart", &"crucible", &"starfurnace",`:

```text
THE CUTAWAY, photographed through the real screen (`CutawayView` on
`SectorScreen`):
  godot --path . --windowed --position 3840,0 -- sheet=CutawayShot keepwindow
      clip=<dir> [weight=light|medium|heavy] [loot=no] [style=...] [seed=N]
      [every=1] [nopause] [nofight] [yard] [bobcheck] [skyclip=<dir>] [orbit]
      [manufacturer=solari] [grade=0..3] [fit=full] [carry=utility] [swaps]
A run at a system with a wreck you killed, parts in the hold and (unless
`loot=no`) something loose in the system. Saves the game's picture every
`every` frames through: the hover outline on your ship, the push-in (backdrop
breaking up, the left panel sliding in), a fitted part and a module in the
hold pointed at (the MODULES page's popup beside each), a part carried (its
rings pulsing), the drop onto a mount, a click on the wreck behind (it shuts
the cutaway and opens nothing), SECTOR LOOT on the bottom bar (this system's
pile in the popup) and a module in it pointed at, the close; then the real
escape menu over the same scene (for the backdrop beside it), then a fight
with a card pointed at (its part lit on the hull). `yard` instead docks at a
station and does it in the Shipyard: your ship on its stands, the outline,
the push-in onto ship and stands, a part and a hold module pointed at, the
close back to the yard. Prints the push-in scale and what 2x needs against
the room. Needs a window. `carry=weapon|system|utility` carries a part of
that slot for the carrying still (its empty mounts' rings and words) and
stops there. `swaps` sets the ship up for the swap marks (`_swap_ship`) and
photographs a part of each slot carried from the hold in both looks, then
one that can go nowhere (`_swaps`), and stops.
THE CUTAWAY'S CLOCK IS STEPPED 1/30 s A FRAME (`CutawayView.fixed_step`), so
the frames, encoded at 30 a second (every=1), show the real 0.4 s push-in
however slowly the window drew them; nothing is saved before the hover.
```

## Wreck click

Inside `_run()`, above `var made: Array = sc._view._made`:

```text
7. THE WRECK is not opened from in here: a click on it is a click on the sky
(Jon: "You shouldn't be able to open a wreck when your ship is clicked on
and in focus"), so it shuts the cutaway; reopened for the rest
```

## Zoom study

Above `func _yard_study(st: StationScreen) -> void:`:

```text
THE ZOOM, STUDIED (`yard yardstudy clip=<dir>`): the yard's clock held, the
blur off, the cutaway's own hull, parts and panel hidden, and every frame of
the push-in saved with the yard's transform on screen (`zoom.json`: scale and
the screen point of the yard's origin, per frame). Laid back over the first,
unzoomed frame, everything in the yard should map to itself; whatever does
not is drawn somewhere the zoom does not reach.
```

## Swap marks

Above `func _swaps(cut: CutawayView) -> void:`:

```text
The marks, through a real drag from the hold (the viewport's own: every
control told it began, the hold's icon hidden as a lift hides it), in both
looks (`MountPoints.swap_look`): a part of each slot, then a weapon that can
go nowhere -- every weapon mount holding a part bigger than the cells it
leaves in the packed hold. `swap_<slot>_<look>.png`; prints what was marked
and where the exploded ship is in the window's px, for crops.
```
