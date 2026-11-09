The reasoning behind `tkg/scripts/ui/YardScene.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shipyard scene

Above `signal service(i: int)`:

```text
The Shipyard: one of Jon's five painted halls, lit and running, with your ship
and the one for sale on their stands, the yard's four services flying over
yours on drones, and the deal on a TV at the bottom right.

IT WAS A HANGAR DRAWN IN CODE, with the services standing in a bay as four
machines. It is the Yard Drones page now -- the artifact Jon built this with,
note by note, and passed at v46 -- and `tools/yard_install.py` installed its
halls, pictures and light (`art/sprites/station/yard/`) with every lamp's
pool worked out ahead of time. What happens here is the part that moves, and
every piece of it names the function on the page it ports.

LAYERS, BACK TO FRONT, as the page drew its frame:

  the hall      the painted hall, lit per pixel (`yard_light.gdshader`)
  the wall      what lives in the wall: the city's tenants and lift cars
  the back      what stands on the floor behind the ships, each with its
                shadow and its reflection, in depth order
  the ships     their stands' shadows, their reflections, the stands, and
                the two hulls (`ShipView`s, lit as the page lit a hull)
  the front     what stands on the floor in front of the ships
  the TV's foot its shadow and reflection
  over          what the light does not reach in the frame: the welder's
                arc, dust in the cones, the ships' names, sparks, flyers,
                the deal TV, the drones and their screens

ON A 30 HZ CLOCK, like the labs and the page, which drew at 30.

766 x 482, the deck's size at 1x: the page was drawn at it, and every number
in `yard.json` is in its pixels.
```

## Module reflections

Above `const FIT_PAD := 24`:

```text
THE MODULES ARE IN THE REFLECTION. A fitted part is not in the hull's
picture -- `MountPoints` draws it over the hull -- so the floor gave back a
bare hull under a ship with guns on it, and the floor lamps threw its shadow
without them. Jon: "Do modules show up in the reflections?" They did not.
So a copy of the ship, mounts and all, is photographed off screen once each
time the ships are stood, and that picture is what the floor reflects and
what the lamps' shadows are cut from. Two frames, then read back.
```

## Stand height

Inside `_stand()`, above `for L: int in pair["at"]:`:

```text
BOTH THE SAME HEIGHT, ALWAYS. Where the hull is not level over the two
caps -- a fin, a pod, the slope toward a nose -- the hull rests on the
higher meeting point, and the stand under the lower part stands up
behind it: its saddle hidden, never short of the hull (Jon: "Why are
the stands two different heights").
```

## Hull middle

Above `static func hull_mass_x(img: Image, ink: Rect2i) -> float:`:

```text
THE HULL'S MIDDLE, in ink columns from the ink's left edge: where its opaque
pixels balance, column by column. Not the ink box's middle: a hull's box runs
out to a tapered nose or a fin hung off one end, and a heavy's long nose put
the box's middle 27 px ahead of where the ship's bulk is. The stands carry
the bulk, so they stand either side of this (Jon: "centered on them").
```

## Stand meets hull

Above `var _cap_cache: Dictionary = {}`:

```text
WHERE A STAND MEETS A HULL, measured off its picture: the first opaque row
of every column (`top`), the columns that reach the seat row -- the cap a
hull's belly lies on (`span`, first and last) -- and the cap's middle (`mid`,
in the picture's columns). The seat (`yard.json`, measured per stand picture)
is the row of the saddle's top face's front edge -- its lip, crease or rim --
and the hull's lowest pixel lies on the row above it, so none of the top face
shows under the belly (Jon, picking B: "sink every level to the front edge of
the saddle's top face"); each stand's `_seat` says which rows are which.
```

## Stand pair

Above `static func seat_pair(under: PackedInt32Array, iw: int, mass: float, cap: Dictionary, seat_rows: int,`:

```text
THE PAIR OF STANDS under a hull: their left edges in ink columns (`at`) and
the hull's lowest row over each one's cap (`c`).

EITHER SIDE OF THE HULL'S MIDDLE. They used to be picked at a flat stretch
near each quarter, each free to wander 16% of the hull, and the medium Korvan's
aft stand walked forward off its quarter to the end of its range: the pair's
middle stood 31 px ahead of the hull's (Jon: "too high and to the left").
Now the two caps' middles always add up to twice the hull's mass middle (to
the half pixel), and only how far apart they stand is chosen.

ON THE BELLY OVER THE CAP, NOT NEAR IT. Each stand used to be measured over a
window 37 px wide against a cap 23 to 35 wide, and seated on the lowest pixel
in the window: a bump just past the cap's edge held the hull up, and the belly
over the cap floated rows above it -- 2 on the medium Korvan, 12 on the light.
Now only the columns the cap is under count, and a spread is chosen where
(in order) no floor shows between belly and cap, the two meet the hull at the
same row, no fitted part hangs over a cap (`hang`, `_hanging`: a gun under the
belly reads as standing on the stand), each cap's belly is level, and they
stand about 48% of the hull
apart (36% to 80%). Where some floor would still show -- a step in the belly
over one corner of a cap -- the hull is let down that many rows more (`sink`).
```

## Stand shadow

Inside `_draw_ships()`, above `var sh: Dictionary = (doc().get("art", {}) as Dictionary).get("stand_shadow", {})`:

```text
EVERY STAND THE SAME SHADOW. Jon: "all of the stands should have the same
shadow. so it doesn't look like they're floating." Each stand also stood
in the floor lamps and threw its own shadow there, different at every
spot, so no two matched; the lamps now pass the stands by (only a hull
throws a lamp shadow, `yard_bay.gdshader`). Every stand gets the shadow
Jon passed under the unclaimed yard's stands ("that shadow checks out"),
one picture measured off that render: the contact at the foot's sides and
the lamps' shadow in front, deepest two rows down and gone before the
hazard stripe four rows down -- "why is there a shadow on the hazard lines
in front of the stand?" A dark band hard under the foot read as floating
four times before, as did the stands' reflections (they have none now).
```

## Ship names

Above `var hide_mine := false`:

```text
The ships' names, over each hull: Silkscreen with a dark outline and a drop
under it. The page drew them at 24 and 16 pixels; in the game, where the
whole yard is shown at twice its size, Jon: "The text for the ships are too
big." So 16 and 8, the next sizes down that keep the font on whole pixels,
the name's baseline 11 rows over the hull and YOURS / FOR SALE 2 rows over.
Your ship's name over it, and its reflection in the floor, off while the
cutaway has it zoomed in: at 2x the sign stood over the parts lifted off the
hull, and the reflection -- a photograph of the ship -- showed through the
blur as a second, ghostly ship under the real one.
```
