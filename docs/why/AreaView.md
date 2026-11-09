The reasoning behind `tkg/scripts/ui/AreaView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Place pictures

At the top of the file, above the class's first member:

```text
The place, drawn. Every node type has a picture before any real art exists,
and a cleared node visibly differs from one you have not touched.

Lit the same way as everything else in the game: from the top of the frame,
cold, with warmth only where something emits it. `_body` is ART_CONTRACT's
two-plane rule — bright top face, bright lip, wall falling into shadow — and
it replaces the flat `_plate` these were built from. A station drawn as three
filled rectangles is three filled rectangles; the same station drawn as three
LIT rectangles is a place with a near side and a far side.
```

## Place art switch

Inside `_draw()`, above `const SHOW_PLACES := true`:

```text
The sector pictures are OFF while their real art is drawn.

Everything below this line still works and is still correct; it is
placeholder art, and placeholder art that is good enough to read is
exactly the kind that quietly becomes the shipped answer. Empty space
says "not drawn yet" in a way a passable procedural station does not.

One switch rather than a deletion: the kit underneath -- the two-plane
bodies, the six-stop ramps, the dither -- is the vocabulary the real
sprites will be checked against, and START already proves the screen
reads fine with nothing in it.

ON, 2026-09-12, by Jon, asked directly and answered "turn it on now,
commission art later". THE WORRY ABOVE STILL STANDS and is the reason this
note has a date on it: the way this ends badly is not that it looks wrong,
it is that it looks fine for a year. Art for these five is commissioned
work, gated on a brief, and until that lands the sector is showing a
sketch of the place rather than the place.

What changed since the switch went in is the argument, not the art. The
sector was empty sky beside your ship, and a system you fly to and find
nothing in reads as a screen that has not finished loading rather than as
a place with nothing in it. EnemyArt is the precedent in the other
direction: it draws every enemy in the game procedurally and nobody has
ever called it a placeholder.
```

## Place picture choice

Inside `_draw()`, above `func _place_name() -> StringName:`:

```text
WHICH PICTURE THIS SECTOR IS, as a name.

Named rather than typed, because the picture does not follow `NodeType`: a
SYSTEM is a battlefield, a derelict or a beacon depending on its option
tags, and a battlefield is two pictures depending on whether it is cleared.
Splitting this out means the sprite and the drawing are chosen by the same
line, so they can never disagree about what this sector is. Empty means
nothing is drawn here at all.
```

Inside `_draw()`, above `MapGen.NodeType.SYSTEM:`:

```text
READ WHAT IS HERE. The three types this replaced each had their own
picture, and the picture is still worth having -- it just comes off
the options now instead of a label chosen before anything rolled.

NONE OF THEM ON LOCAL (Jon, Oct 21: "I don't want the beacon to show up
at all. I want to see the actual event of that planet/POI"). The
beacon, the derelict and the battlefield were pictures picked from the
options' tags, standing in for events that LOCAL now shows as
themselves: the event at the place the ship is, opened as GO opens it,
its own subject drawn (`LocalEventDrawer.auto_open`, `LocalSubject`),
and the hulls of the fights fought there (`show_wrecks`). On LOCAL
(`site` set) a system draws no place picture; the sheets (`ANY`) still
draw every one of them.
```

Inside `_draw()`, above `MapGen.NodeType.CORE, MapGen.NodeType.PULSAR:`:

```text
THE CORE AND A PULSAR ARE THE SYSTEM'S OWN STAR, and LOCAL's sky
already draws that star (`LocalSky`: the core's hole is the black
hole every style shares, `CoreLegacy`; the pulsar and its beams).
A place picture here drew it a second time, beside your ship --
Jon, Oct 13, at the core: "why are there two black holes lololool".
`_core` and `_pulsar` stay, for `-- sheet=PlaceSheet`.
```

Inside `_draw()`, above `var tex: Texture2D = DB.place_sprite(what)`:

```text
ONE DOOR, and the moving parts stay on this side of it. The two places
that animate do so as OVERLAYS -- the station's two navigation strobes
and the beacon's five walking rings -- so they are drawn after the
picture whether the picture was generated or drawn. That keeps the
asset set at one still frame per place: a sprite inherits the motion,
and nothing has to be authored at the 12 Hz this repaints at.
```

## Station and beacon

Inside `_draw()`, above `func _station_lights(c: Vector2) -> void:`:

```text
Navigation strobes: the one cold light on it, so it does not read as a
furnace.

THEY STROBE, and out of phase with each other. A navigation light is the
one thing on a station that genuinely blinks, so it is the one thing here
that earns an animation -- the windows stay lit, because a window going
dark is somebody walking about and this game has no people in it you can
see. Long dark, short bright, two different periods: in step they would be
a heartbeat, and a heartbeat is a rhythm the sector does not have.

SEPARATE SO A SPRITE CAN KEEP IT. This is the only moving part of the
station, and it is two three-pixel squares -- so the generated plate is a
still station with its lights off, and these go on top of it exactly as
they go on top of the drawing. Baking them into the art would cost a frame
set for six pixels.
```

Inside `_draw()`, above `func _strobe(period: float, offset: float) -> float:`:

```text
One strobe: dark most of the period, then a short bright flash.

Deliberately not a sine. A sine spends half its time near full and reads
as a pulsing glow; a light that is off and then briefly on reads as a
machine signalling, which is what this is.
```

Inside `_draw()`, above `func _beacon_rings(c: Vector2, tint: Color) -> void:`:

```text
The rings, which are the thing the beacon is DOING.

SPLIT FROM THE LAMP BECAUSE THE BUOY SITS BETWEEN THEM. Rings go down
first and the lamp goes on top, so a generated buoy has to land in the
middle of the sandwich -- an overlay drawn wholly after the sprite would
paint the transmission over the transmitter.
```

Inside `_draw()`, above `for i in 5:`:

```text
THE RINGS GO OUTWARD, because the rings are the thing it is doing. A
beacon drawn as five fixed circles is a diagram of a transmission; the
same five walking outward and dissolving is a transmission. It costs
one modulo and it is the difference between a picture of a place and a
place -- and this setting's cheapest horror, per lore.md, is a system
that is empty and still talking.

Five rings on one cycle, so a ring leaves the buoy exactly as the
outermost reaches the edge and fades into the void. Nothing appears or
vanishes; the colour ramp was already taking them to the background
colour at the far end, so the loop hides itself.
```
