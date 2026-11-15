The reasoning behind `tkg/scripts/ui/ExchangeScene.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Exchange room

Above `const VIEW_SIZES := ["s", "m", "l"]`:

```text
The Exchange: one of Jon's five rooms, with your hold standing in it.

THE SHOP'S ROOM, FACING THE OTHER WAY. Jon laid out one room per development
level on the Exchange's own bench (`room_bench.py --deck exchange`), and
`tools/room_install.py` installed them beside the shop's, under
`decks.exchange` in rooms.json. Everything `ShopScene` does -- the plate, the
openings, the lamps, the light, the dust, the counter's lit marks -- this does
the same way, from the same code. What differs is three things.

THE HOLD STANDS WHERE THE RACK DID. It is three frames, one per hull size,
fitted round a 4x3, 5x4 and 6x5 grid of 40px cells (`tools/cage_fit.py`). The
room was laid out round the heavy frame; a lighter hull's stands on the same
spot, centred, its feet on the same floor, as the bench previews it. The frame
is drawn here, between what stands behind the furniture and what stands in
front of it, and the hold itself -- `HoldGrid`, live, packable, draggable --
stands in its opening (`hold_opening`).

THE WALL IS THE STATION'S. An Exchange stands in its own station's shop
plate: the shop picks one of its level's three plates off the seed and so does
this, so two decks of one station are built of the same stuff. Jon laid each
Exchange out on one wall and chose this over keeping it (2026-09-27, "A"):
a station's shop and Exchange match, and each of his rooms stands on all
three of its level's walls. The wall in his layout is only the fallback.

SPACE OUTSIDE, AND IT IS THIS STATION'S. The view is `SpaceBackdrop` -- the
sky the sector shows when you are here -- drawn once into a picture the size of
the room, with its world framed in the room's biggest clear window
(`sky_frame`, worked out by the installer). A station arm was generated to
stand across it and Jon cut all five: "a disembodied space station arm
doesn't make sense" (2026-09-27). Nobody walks past; now and then a ship does.
```

## View not lit

Above `const VIEW_SIZES := ["s", "m", "l"]`:

```text
THE VIEW IS NOT THE ROOM'S TO LIGHT. The shop hands a window over to the
room across a few pixels; on black space that band came out as a grey ring
round the door's edges and round everything standing in front of it (Jon,
2026-09-27: "why is there a weird outline ?"). So the room carries its view
pixel for pixel, one channel per hold size (`room_install.view_masks`), and
the light leaves exactly those pixels alone.
```

## Plate ahead

Above `func load_plate_ahead() -> bool:`:

The Exchange's plate load is the shop's plus its sky: `SpaceBackdrop.setup`
bakes the planet pixel by pixel, 22 to 47 ms, against ~7 for the rest.
The sky goes first: made with its bake only begun (`_ensure_sky(true)`), then
painted `SKY_STEP_PX` pixels a frame (`SpaceBackdrop.bake_step`,
`docs/why/SpaceBackdrop.md#sliced-bake`), its viewport left on `UPDATE_DISABLED`
until the last slice and set to `UPDATE_ONCE` then. Then the shop's steps: the
art read ahead a few pieces a frame (`warm_list` adds the hold's frames, its
hook and the view mask), then the plate. `setup` returns early for the node it
already has, so `_choose_view`'s `_ensure_sky` then costs only the redraw; an
ordinary `_ensure_sky` finishes any bake still in slices first. See
`docs/why/StationScreen.md#rooms-ahead`.

## Fleet ahead

Above `static func fleet_ahead() -> bool:`:

The ships that pass the Exchange's window are 34 rows of `flyby.json`, a far and a near picture
each: 68 textures, read the first time any Exchange poses its cast, which is inside its first
`_draw`, on the first frame of the first ride there after the game starts. That was the 76 ms
first visit to the Exchange after launch (Nov 14, windowed; later dockings 8 ms, since the list is
static and kept for the life of the game). `RoomsAhead` now reads it a ship a frame once both
rooms are in; `_fleet_list` reads whatever is left at once, so a ride that comes first is no
worse than before, and the list is in the file's order either way.
