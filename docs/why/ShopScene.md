The reasoning behind `tkg/scripts/ui/ShopScene.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shop room

Above `const ROOMS_DIR := "res://art/sprites/station/rooms/"`:

```text
The room the Promenade's shop stands in: one of Jon's fifteen.

THE ROOM IS HIS AND IT IS DATA. Jon laid out three rooms per development
level on the room bench, and `tools/room_install.py` put them in
`art/sprites/station/rooms/` -- every plate, prop, lamp and door at the size
it is drawn, and each room's light worked out ahead of time. A station picks
one of its level's three off its seed, the way it picks its backdrop, and
this draws it the way the bench draws it: the same passes in the same order,
the same pixels. Nothing about where a thing stands is decided here.

THE BENCH IS THE REFERENCE. Where this file and `tools/room_bench.tmpl.html`
disagree, this file is wrong. Each function below names the bench function
it ports.

FIVE LAYERS, BECAUSE THE RACK AND THE COUNTER ARE LIVE. The stock on the
rack can be picked up and the counter takes it, so both are nodes of their
own and the room is drawn around them:

  this node   the plate, the openings and the concourse through them, and
              whatever the bench draws before the furniture or clear of it
  (furniture) the rack and its stock, the counter -- `StationScreen`'s
  front       what the bench draws after the furniture and over it: the
              haze, a prop Jon stood in front, the lamps
  light       the room's light, over all of the above (`ShopLight.Overlay`)
  glow        dust, lamp glass, lit panels, and the shop's own marks

`StationScreen` stacks them in that order; the three above the furniture
come from `front_layer`, `light_layer` and `glow_layer`. Which side of the
furniture a thing goes is `room_install.py`'s call, made from the bench's
draw order: Jon keeps his racks and counters in the WALL band, where they
neither cast a shadow nor sit in one, so the haze comes in front of them.

NO LIVERY. The old room tinted its trim in the manufacturer's colour and hung
cables in front; the bench has neither, so neither does this (the port
plan's option 2A). Other decks keep theirs.
```
