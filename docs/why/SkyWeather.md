The reasoning behind `tkg/scripts/ui/sysmap/SkyWeather.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Weather scheduler

Above `const SkyBakeS := preload("res://scripts/ui/sysmap/SkyBake.gd")`:

```text
THE SECTOR MAP'S WEATHER (Jon, on the nebula skies' first lightning: "Yeah I
love this. Great job on all of this. More weather!"). Every system has some
now: inside a nebula its cloud's own (`sky_nebula.gdshader`), round a pulsar
or the core their own, and in a calm sky the quiet kind -- a far star
swelling for a moment, a comet, a red giant dimming.

ONE SCHEDULER, TWO SLOTS (the build spec is the scratchpad's
`weather/catalogue.md`):
  * slot A holds one medium event (M, the weather), showpiece (SP, rare, the
    screenshot) or reactive one (R, set off by the ship) at a time, with at
    least 6 s from the end of one to the start of the next;
  * slot B holds one small one (S): it may run under an M, never under an SP,
    never within 150 px of slot A's spot, never in the 2 s before slot A is due.
Each system rolls its temperament (calm, steady, stormy: how OFTEN, never how
long -- the lesson of "speed changes how often, not how slowly"), and its
favourite medium, three times as likely as the rest, so two emission systems
differ: one leans to storms, another to jets. The timing draws come from the
clock, so each visit plays differently.

NOTHING STARTS until the palette has been found from the system's first
picture and a second has passed, so no weather is ever baked into it. With
reduced motion nothing starts at all and a live event is cleared on the next
frame. A held clock (an event page being read, a glide, an insertion, a zoom)
stops slot A from starting anything new; a live event always plays out.

WHERE EACH IS DRAWN. Far sky never zooms: `sky_nebula` slides by `neb_off`,
`sky` by `sky_off`, and an event's place is kept in that sky's pixels. In the
system, things scale with the map: the comet and the dust puff are nodes in
the place's own picture (under the palette, under the worlds), the pulsar's
and the hole's events are in their own painters. Every event's place is kept
clear of the ship, the worlds, the star, the labels and the selection
(`spot`), and its added light fades out under the ship (`g_ship`).

Silent: nothing here plays a sound. The pulsar's giant pulse and the
magnetar land on a beat its ambience already sounds.
```

## Event cadence

Above `const CADENCE := {&"emission": Vector2(12, 30), &"dark": Vector2(12, 30), &"remnant": Vector2(15, 40),`:

```text
slot A's medium events, seconds from one start to the next (times the
temperament). Halved on Oct 5 (Jon: "A player would never see some events
that take 10-45 minutes per event"): the rarest took 30-45 min to come round.
```

## Weather colours

Above `const RAMP := {}`:

```text
THE WEATHER'S OWN COLOURS, appended to the system's palette (`SystemPalette.build`'s
`extra`), by sky. NONE, MEASURED: the gate is that the sky with no event is
the same block for block with and without them (SystemShot `wramp=0`), and
every one tried -- emission #ffe8f0 #ff9ab4 #b8f0e8, reflection #dcecff
#b8d4ff, remnant #7af0e0 #e8fff8 #c0d8ff, dark #e0d8ff #b49cff -- took 0.03
to 0.28% of the plain sky's blocks (its star points, the cluster's core, the
brightest strands) and moved a few dither pairs. The events use the colours
the sky's palette already holds (its own median cut and the sun's steps).
```

## Warp-in weather

Above `func arrive(warp_t: float) -> void:`:

```text
A FRESH WARP-IN (`SystemMapScreen.show_system(..., arrived = true)`): the
bowshock when the streak ends, and the first weather sooner. Only ever on
arrival (Jon, Oct 5: off as "weird" in every sky, then back once he heard it
was the arrival's alone).
```

## Frame words

Above `var _ui_at := -1`:

```text
THE FRAME'S OWN WORDS, which the overlay does not place: the goal line and
its step at the picture's top left (`GoalLine`), the ship's status under
them, and the scale bar and LOCATION at the bottom right. The status line's
box is its own words' (`SystemOverlay.status_rect`): a fixed 300 x 24 at the
top left was where the status stood before Oct 20, and it kept nothing off
the line now drawn under the goal (at y 37 to 49), nor off a twin's longest,
327 px "LEAVING ORBIT · TO A CLOSE ORBIT OF <system> B" (the words review).
(worked out once a frame: a spot is tried at many points)
```

## Label clearance

Inside `clear_at()`, above `for r: Rect2 in _labels():`:

```text
(a negative grow -- the belt's looser keep-out -- shrinks a label's 14 px
box to nothing; a box turned inside out made Rect2 complain every check,
hundreds of times a visit)
```

## Emission cluster

Above `func em_cc() -> Vector2:`:

```text
THE YOUNG CLUSTER AN EMISSION CLOUD IS LIT BY: in SIMPLIFIED it is the system's
own sun, at its sky pixel with no pan (`sky_field.gdshader`'s `cc`), so the
tide washes out from the sun, the glints wink round it and the jets leave the
tips of the pillars that reach toward it -- with two suns their balance point,
where the sky is baked round (`SystemView.sky_c`, ruling 23).
```

## Comet orbit

Inside `_p_comet()`, above `for b in L.bodies:`:

```text
(the comet swings round star A, the origin of `comet_pos`: its perihelion by
the inner orbit ROUND A -- in a twin the world circling A, not one round B
or the pair, whose orbits are about other centres. A close pair has none
round A, and at a lone sun's 96 px its path could cross star B, 150 to 170
px off: there the inner orbit round both, at least 2.4 separations out, so
the comet passes outside the pair)
```

## Pulsar knot

Above `func _p_fog(ev: Dictionary) -> bool:`:

```text
(it was placed at a random angle with no keep-out at all: filmed, the knot
sat under the ship, its orbit and its IN ORBIT line, inside the pulsar's own
bright cloud where it could not be seen; now out in the darker shell, clear)
```

## Comet drawing

Above `class Comet extends Node2D:`:

```text
A COMET (`comet`, and the sungrazer diving at the star): drawn in the place's
own picture after the belts, under the palette, the star, the worlds and the
lines, in 2x2 blocks. A single block far out; nearer the star a soft head
and two tails -- a straight blue one pointing away from the star, a broader
warm one curving behind along its path. Its tails turn in 2 degree steps and
grow in whole blocks, so nothing between moves by part of a block.
```

## Comet tails

Inside `_apply_bow()`, above `var away: Vector2 = view.screen(pw.x, pw.y) - view.screen(sa.x, sa.y)`:

```text
THE TAILS, away from the star -- from where the head truly is, not its
block: the block steps across then down, its angle wobbles, and the
tail flicked between two of its 2 degree steps
```

## Points of light

Above `class Points extends Node2D:`:

```text
POINTS OF LIGHT OVER THE DUST: the hot point at the heart of a few far-sky
events -- a new star, the pearls' beads, the fan's hidden star. The cloud's
shader draws them too, but under the depth sheets, where the dust dims a
white star to a grey speck; here they are drawn after the sheets, where the
twinkling stars are, a 2x2 block each (and a dim plus for the new star), in
the place's own picture before the palette. Each is [screen point, colour
(its alpha the strength), the plus's share].
```

## Real comet

Above `class RealComet extends Comet:`:

```text
The comet you can fly to (`CometPath`, Phase 13). It moves on the weather
comet's own path (`comet_pos`), and since Jon's "K3" (Nov 9) it has a bigger,
brighter look of its own (see Real comet look). What it adds:

- Its path ahead, dotted on the plane in blocks every DOT_PX, from its head to
  where it leaves. A dotted line is no world's ring (those are solid), and it
  shows where the comet will be before it gets there, which is the whole idea
  of option C. Before it comes in, the whole path shows.
- In RADIANT, a wider coma: the halo is 1.6 times the radius, in the same
  dithered steps (the "draw light as light" rule).

It is made in `setup` and steps itself (`_process`) from the view's clock.
PAINTED needs nothing new: its age is held in poses (8 a second), as `_apply`
holds the weather's. Reduced motion does not clear it as it clears the weather:
it is a place, not weather. It never draws smaller than its size at
`a_min` (`CometPath.A_MIN`), so a thing to click always reads.
```

## Real comet look

Above `const ION := ...` in `class RealComet`:

```text
Jon, Nov 9 ("K3"): drawn as the weather comet, the comet you chase was too
small, and its dust tail short and faint. It needs to read at a first glance as
the thing to go after (danger and goals must be obvious). Its own look, still
pixel art in 2x2 blocks with dithered steps and no smooth gradients:

- a 4 px white head inside a coma of about 4 blocks' radius, white to pale
  cyan to blue in three steps, the faint outer rings on the checker;
- a long gold dust tail (DUST_N, about 36 blocks), widening to about three
  blocks a side, leaving about 14 degrees off the away line (DUST_OFF) and
  bending further (BEND) to the side it trails from, fading from cream through
  gold to rust, its edges dithered. Leaving along the away line, it hid the
  blue tail under it (the first K3 render);
- a straight blue ion tail (ION_N, about 28 blocks) pointing away from the
  light, its last 40% dithered.

Size k is 0.75 to 1.0 by nearness to the star (never below the `a_min`
floor's), times the map zoom held to 0.9 to 1.5. Each block is laid once
(`_lay`), the ion tail first, so overlapping parts never double their alpha
into a white smear and the blue is never painted over. The
weather comet keeps its own drawing, unchanged.
```

## Real comet and the palette

Above `var _since_pal := 0` in `class RealComet`:

```text
The map cuts its palette from the system's own first full picture of `_scene`
(SIMPLIFIED and RADIANT; `_pal_cache` keeps it for later visits). The weather
never draws before that (`SkyWeather._process` waits for `_palette_built`). The
real comet did: after K3 its big gold dust tail went into the cut and pulled an
olive step into RADIANT's star glow (Nov 9, the coordinator's check: there with
the comet, gone with it hidden, the same in two runs). It now shows only
PAL_WAIT frames after the cut, as LOCAL's band comet does after LOCAL's.
```
