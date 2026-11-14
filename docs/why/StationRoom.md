The reasoning behind `tkg/scripts/ui/StationRoom.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Room design

Above `var dev: int = MapGen.Development.CITY`:

```text
The room a station deck happens in: a back wall, a floor, and the lamps over
it. Every deck but the Shipyard's hangar is one of these with its own furniture.

ONE ROOM, FOUR DECKS. The Promenade got a room first and everything in it --
the palette, the tint, the lamp count, the floor laid in widening courses, the
light pools drawn after the floor -- was worked out the hard way, one wrong
screenshot at a time. The Exchange, the Hiring Hall and the Laboratory need
exactly that room with different things standing in it, and three copies of
two hundred lines is three places for the next lesson to be learned only once.
So the room is here and each deck says only what is DIFFERENT about it, in
`_dress_wall` and `_dress_floor`.

A PLACEHOLDER THAT IS ALSO THE FALLBACK, like `YardScene`. The layout is the
part worth settling with rectangles, and every answer is a constraint the art
will have to meet. If a generated plate never lands, this is what the station
looks like.
```

## Palette

Above `const WALL := Color("#0d141d")`:

```text
THE STATION'S OWN PALETTE, and deliberately the berth's numbers.

`YardScene`'s header records why they are darker than they look like they
should be: a mid-grey room puts mid-grey objects against mid-grey and every
silhouette goes soft. The decks reading as one station is worth more than any
one of them reading well alone.
```

Inside `_draw()`, above `draw_rect(Rect2(0.0, 0.0, w, floor_y), WALL)`:

```text
--- THE BACK WALL, AND IT IS THE DARKEST THING IN THE ROOM.

It was `PLATE` for one pass, which is the colour of the FURNITURE -- so the
shop's rack and till read as dark holes cut in a lighter wall. Everything
standing in a room has to out-read the room. Untinted, for the reason
`_tint` gives at length.
```

## Livery tint

Above `func _tint(c: Color) -> Color:`:

```text
A colour pigment-shifted toward whoever holds the station.

ON THE TRIM, NOT ON THE WALLS -- which is the whole finding.

A lerp moves each channel by a fraction of ITS OWN GAP, and out of a colour
this dark the gaps are wildly uneven: Solari's #ed9b22 against #0d141d is 224
of red and 5 of blue. Any weight at all therefore does not tint a wall, it
DESATURATES it -- at 0.12 the shop's wall came out #2f2d29 and at 0.06
#1a1c1d, both neutral warm greys where the station is meant to be cold blue.

So big surfaces keep the station's colour and the livery goes on the EDGES:
joints, studs, conduit, window frames, floor courses. That is how a livery
works anyway -- nobody repaints a hull, they paint the trim -- and a 2px line
can afford to be orange.
```

## Plates

Above `func plate_id() -> StringName:`:

```text
Which plate this room wants, or `&""` for none.

KEYED ON THE DECK, NOT ON DEVELOPMENT, because the plate is a BACKDROP and
carries no lamps. The lamp count is what development changes, and lamps are
drawn over the plate from `_lamps()` -- so one plate serves an outpost and a
capital alike, and the twelve this used to need are three. Decks override
this; the base is the plain room.
```

Above `var _plate_key: StringName = &""`:

```text
The room as two generated layers, or `false` if either is missing.

TWO LAYERS BECAUSE THE LIVERY TINTS TRIM ONLY, which is `_tint`'s finding
above: a wall lerped toward a manufacturer colour desaturates instead of
tinting. So the plate ships as `<id>_wall.png` flat and `<id>_trim.png`
through `_tint`, and the orange lands on the joints and the courses where it
belongs.

RESOLVED OUTSIDE A DRAW CALL AND REMEMBERED.

A TEXTURE FIRST TOUCHED INSIDE `_draw` RENDERS WHITE. Resolving one there
hands the renderer a resource whose GPU side is not ready for the commands
being recorded, and the sampler falls back to white -- every texture, every
size, `draw_texture` and `draw_texture_rect` alike, while `draw_rect` on the
same item draws correctly. A room draws about twice in its life, so it keeps
that white for good. Rect-drawn rooms never hit it, which is why it waited
for the first plate to appear.

Keyed on the id so a deck that changes development level reloads rather than
keeping the plate it was born with; `dev` is set after `_ready`, so loading
there would cache the wrong one.
```

Inside `_draw()`, above `_draw_openings(w, h, floor_y)`:

```text
A plate is the ROOM AS A BACKDROP -- walls, deck, and nothing that
varies. The lamps go on over it because their COUNT is development and
their COLOUR is the deck, and the furniture goes on over that because
it is per-deck and often live: the Exchange's cage is measured off the
hold grid every redraw, and the service rigs reach for whatever hull
is parked. None of those can be baked and none of them are meant to be.
```

Inside `_shaped_opening()`, above `var art: Texture2D = _opening_art.get(skin, null)`:

```text
FROM THE CACHE, NEVER `load()` HERE. Resolving a texture inside a draw
call hands the renderer a resource whose GPU side is not ready and it
samples opaque white for good -- the warning at the top of this file,
broken nine hundred lines below where it is written. Every opening frame
in the game rendered as a solid white rectangle because of this one line,
and it was invisible in the bench because the bench never ran this path.
```

## Lamps

Above `func _lamp_rects(w: float, _floor_y: float) -> void:`:

```text
The lamps as sprites, or `false` if there is no art and rectangles it is.

THE COUNT AND THE POSITIONS STAY THE ROOM'S. Art supplies the fixture and the
shape of the light; `_lamps()` says how many and `w * (i + 0.5) / n` says
where, so an outpost still reads as two lamps and a capital as six off one
plate. The glow is drawn through `_light()`, which is how the Laboratory gets
cold light out of the same cone everything else lights warm.
The lamps as rectangles: the fallback, and what the room has always drawn.

THE LIGHT LANDS ON THE FLOOR. A lamp that glows and lights nothing is a
sticker; the pool underneath is the half that makes the room have a source,
and it is drawn later, after the plating it falls on.
```

Inside `_draw()`, above `_dress_floor(w, h, floor_y)`:

```text
NO LAMPS ON THE ART PATH. The generated hood and its drawn cone and
pool read as stickers over a room that is otherwise made, and were
cut. `_draw_lamp_art` stays for when lighting comes back as art that
belongs; the drawn fallback room below still hangs its own.
```

## Room layers

Above `var place_seed: int = 0`:

```text

A ROOM IN DEPTH, NOT A ROOM ON A PANEL. The back wall opens -- a window onto
the concourse outside, a door onto a corridor -- and what is seen through each
opening is a generated view of somewhere else on the station, with people
walking past in it. In front of the whole deck, furniture included, hang dark
cables. Nothing here moves the camera, so the depth comes from what a still
picture can do: overlap, far things hazier than near ones, a dark frame in
front, and near things moving faster than far ones.

ALL OF IT IS THE PLATE PATH'S. A deck with no art keeps the rectangles it had.
```

## Layer rate

Above `const LAYER_HZ := 30.0`:

```text
How often the moving layers redraw: 30, as the room bench does.

It was 12, the sector view's rate, on the grounds that pixel art moving at
60 Hz reads as sliding. That does not apply here: a walker's body only moves
when its pose changes (planted feet, Jon's pick), and poses change 4 to 13
times a second -- so at 12 Hz every pose was held for 83 or 167 ms at
random, and the fastest walker skipped poses outright. At 30 the holds are
even and nothing is skipped. Walkers, drones and the drawn figures are the
only things on this clock.
```

## Backdrops

Above `const BACKDROPS := {`:

```text
ONE PLACE BEHIND THE WHOLE WALL, when there is one: every opening shows the
part of it behind that hole, instead of each opening picking its own view.
Placed by `_draw_openings` so its walkway meets this room's floor.

EVERY ONE IS 800x400, AND THAT IS NOT A STYLE CHOICE. `_bd_pos` centres the
picture on the wall and stands it on the floor line, so on the 740x431 panel
it sits at (-30, -47) -- past both sides and over the top. The set this
replaced was 808 wide but only 286 to 352 tall, which left between 1 and 67
pixels of bare wall above it, and an opening dragged high showed the gap.
Drawing those smaller to widen the view only uncovered more wall. Any
backdrop added here has to reach as far.
ONE POOL PER DEVELOPMENT LEVEL (Jon, 2026-09-25). The promenade behind the
wall is part of how a station says how built-up it is, so a squat never
looks out on a capital atrium. Each is `backdrop_<level>_<name>.png`; the
first set of 25 (arches, archive ... vitrine) is retired, files kept, and
`room_bench.py` fails its build if this and its VIEWS ever disagree.
```

Above `const REFLECTIVE: Array[StringName] = [&"outpost_hydro", &"outpost_vending"]`:

```text
FLOORS THAT SHOW A REFLECTION: the walkers on these are drawn a second
time, upside down under their feet and faint (Jon, 2026-09-25). Only the
backdrops whose floor was generated polished; a reflection on grating
would be a lie about the floor.
```

## Walkers

Above `const WALKERS := true`:

```text
PEOPLE ON THE CONCOURSE, as pixel-art sprites on the backdrop.

THEY BELONG TO THE BACKDROP, NOT TO A WINDOW. Each one stands on a walk line
measured for that particular backdrop and moves in the picture's own
coordinates, so two openings onto the same stretch of concourse show the
same person in the same place. The procedural figures this replaces were
drawn per pane in lanes, which meant two windows side by side showed two
unrelated crowds of the same three silhouettes.

A FUNCTION OF THE CLOCK, not a list that steps: each walker's position comes
from the time and its own seed, so nothing has to be kept in step and a room
that was hidden picks up wherever the clock says it should be.
```

Above `func _walkers(r: Rect2, i: int) -> void:`:

```text
People walking past on the far side of the glass, in three lanes.

DEPTH BY SPEED AND HAZE. The near lane is lowest, tallest, darkest and
fastest; the far lane is higher, smaller, paler and slower. On a picture that
never pans, that difference in speed is the whole of the parallax.

A FUNCTION OF THE CLOCK, not a list of walkers that step: each one's place is
computed from the time and its own seed, so there is no state to keep in step
and a room that was hidden picks up exactly where the clock says.
```

## Walk pace

Above `const WALK_PACE := 40.0`:

```text
The pace the concourse walks at, and it is NOT a free number. A walker's
frame is chosen by the distance it has covered, so this sets how fast the
legs move as well as how fast the body crosses.

40, ON JON'S CALL, AND IT BREAKS THE RULE THE CYCLES WERE CUT TO. At 20 a
thirteen-frame cycle plays about 4.7 frames a second, inside the band where
the eye separates steps; at 40 the same cycle plays 9.5, which is half again
past the 6.3 he once rejected outright as jitter. Every cycle in
`walker_strips.json` was measured and judged at 20.

It is here at 40 anyway because his eye has overruled that arithmetic six
times running -- five quality gates and a drone bob depth, every one of them
fitted to his earlier verdicts and broken by his next one. A number nobody
has watched is worth less than a look.
```

## Shaped openings

Above `func _shaped_opening(r: Rect2, tex: Texture2D, skin: StringName) -> void:`:

```text
A HOLE THAT IS NOT A RECTANGLE. An arch, a canopy, a torn breach: the sprite
carries the frame, and the station shows through the shape cut in it.

THE SPRITE CANNOT TELL US WHERE THE HOLE IS. Both the hole and the air around
the frame are transparent in it, so filling "everywhere the sprite is clear"
paints promenade in a square all round the opening -- which is exactly what
the bench did until the hole was measured out separately. `opening_holes.json`
holds the inside as spans of [y, x, width]; we fill those and nothing else,
then lay the sprite over the top.
```

## Openings

Above `func _frame(r: Rect2, sill: bool) -> void:`:

```text
An opening's frame: the authored bezel, nine-sliced round the opening.

THE BEZEL IS A SPRITE, NOT RECTANGLES -- `room_plate.py frames` records why.
The livery goes on a light bar in its head, which is the one place on a frame
a manufacturer would put a colour; with no bezel art the old drawn frame stays
as the fallback.
```

## Walker picking

Inside `_pick_strip()`, above `if near.is_empty():`:

```text
NOTHING NEAR, NOBODY DRAWN. Every sprite is 74-87px, so a 60px or 40px
line used to get the nearest one anyway -- a 74px curlyB on all nineteen
far lines, and on eight backdrops everyone was curlyB. A far line keeps
the drawn figures until sprites that size exist, as the bench does. A
drone has no line height to match, so it still takes the nearest.
```

## Figures

Inside `_figure()`, above `var head := maxf(3.0, roundf(tall * 0.16))`:

```text
A PERSON, NOT A POST. The first cut was a block with a head the same width
and read as a row of bollards. What says "person" at twenty pixels is the
head narrower than the shoulders, a gap for the neck, a waist narrower than
the chest, and arms and legs that swing.
```

## Foreground

Above `func foreground() -> Control:`:

```text
The layer IN FRONT of the deck, furniture and all, as its own node.

ITS OWN NODE BECAUSE THE FURNITURE IS. A deck's rack, till and cage are
children of the screen stacked over this room, and nothing this room draws can
reach above them. So the screen adds this after the furniture, and it draws
the cables that make the whole deck sit behind something.
```
