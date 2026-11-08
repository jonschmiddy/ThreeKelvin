The reasoning behind `tkg/scripts/ui/SpaceBackdrop.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sky rules

Above `enum Kind { DEEP, PLANET, GIANT, ASTEROIDS, STAR, FLEET, CORE }`:

```text
What is out there, behind the fight.

The void is never flat black — but until this existed every sector WAS the
same black with a different wash over it, so a shipyard in a capital and a
beacon at the edge of nothing looked like the same place. This paints one
large body per system, and a starfield whose density and colour follow the
same seed.

Two rules hold the whole file together.

**It follows from the place.** A station orbits something, so a station
sector has a planet in it. A beacon is put where there is nothing to put it
near, so an event sector is empty sky. Derelicts drift where the rocks are,
fauna follow the gas giants, and a fleet is only ever in space somebody
holds. Nothing is rolled freely: the roll picks between the things that are
true of that node, and the node's own axes — development, security, berths —
decide which list it rolls on. That is what makes the sky readable. If you
have learned that lit cities mean a settled world, an unlit one means
something.

**It is fixed for the run.** Everything derives from the node index, so a
system has the same sky every time you fly back to it and none of it is
saved. The planet texture is baked once into an Image on arrival; the rest is
a few hundred rectangles regenerated from the seed each redraw, which is why
nothing here is stored in an array.

It draws between the wash and the nebula gas, never over the ship, and it is
deliberately dim — this is depth, not subject matter. A planet you notice
more than the thing shooting at you is a bug, so every surface colour is
pulled toward VOID before it is written.
```

## Palette

Above `const HUES := {`:

```text
Palette anchors, in hue-sat-val, one row per world class:
[hue, hue jitter, saturation, value]. Not UITheme constants, because a planet
is the one thing in the game that is supposed to have a colour nobody chose —
the theme's job is to keep the interface coherent, and this is sky. What
keeps it in the game's register is the last step of _surface(): everything is
mixed toward VOID and lit cold.
```

## Framing

Above `var frame_in: Rect2 = Rect2()`:

```text
WHERE THE WORLD IS FRAMED, when something other than the sector draws this
sky. The Exchange hangs it behind a room whose counter and floor cover the
bottom third of the view, which is where most worlds sit: of 60 station
skies behind its five rooms, 8 showed any of their world through a window
(2026-09-27). Given a rect in view pixels, the world is drawn there instead:
whole and centred when it fits, its upper limb rising into the lower part of
the rect when it does not.

THE LIMB, NOT THE PICTURE'S EDGE. The baked world carries a margin of halo,
ring and moon round its disc, a fifth of its height on a big one, so placing
the picture's top put the planet itself below a hangar door's sixty-pixel gap
entirely. What is placed is the disc: `_disc_top` down the picture, `_disc_r`
across.
```

## Bake timing

Above `var _node: MapGen.MapNode = null`:

```text
The system whose sky this is, and the view height its world was baked for.

Both exist because of when setup() is called. The sector screen tells this
control where you are while it is still building itself, and a Control has no
size until the layout pass at the end of the frame — so a world baked inside
setup() is sized against a height of zero. The bake waits for a size instead,
and runs again if the view ever changes height enough to matter.
```

## Pick rolls

Above `func _pick_open(n: MapGen.MapNode, r: RandomNumberGenerator) -> int:`:

```text
FIGHT, and anything the map adds later: the axes decide.

One roll per question, not one roll re-read. A single number tested against
0.42 and then against 0.55 is not two independent chances — passing the first
test has already eaten most of the range the second one needed, and the
weights stop meaning what they say.
```

## World bake

Above `func _bake_world(n: MapGen.MapNode) -> void:`:

```text
Bakes the planet, its rings and its moon into one texture.

Baked rather than drawn, for two reasons that both matter. A lit sphere is
per-pixel work — normal, terminator, dithered ramp — and doing that in _draw
would redo it every time a card moves. And an Image lets the ring occlude the
planet at the top and the planet occlude the ring at the bottom by writing
pixels in order, which draw calls cannot do without splitting the ring in
half and hoping the seam lands somewhere invisible.
```

Inside `_bake_world()`, above `var want: float = maxf(40.0, frac * maxf(size.y, 240.0))`:

```text
Source resolution follows the size it will be drawn at, so a world is
about three screen pixels to the source pixel whether it fills the frame
or sits in a corner. Fixing the source instead would make big worlds mush
and small ones needlessly expensive.

The ceiling is measured, not guessed. A lit sphere costs about five
microseconds a pixel in GDScript, so radius 64 is roughly 95 ms of bake
and radius 78 is 140 — one frame you do not notice on arrival against
eight you do. Past that a world grows by drawing its pixels bigger.
```

## Composition

Inside `_bake_world()`, above `var shot := r.randf()`:

```text
Composition, in four shots, and `frac` is the RADIUS as a fraction of the
view's height — so 0.6 is a body wider than the frame with its centre off
the bottom edge, and 0.08 is a dot. Reading it as a diameter is how the
first pass ended up with corner accents three hundred pixels across.

A limb rising out of the bottom edge is the shot that reads as "in orbit",
so stations get it most of the time and everything else is further away.
The top-left is never used: the sector readout is written there, and text
over a planet is text you cannot read.
```

## Light direction

Inside `_far_sun()`, above `var at := size * 0.5 + _light * Vector2(size.x * 0.46, size.y * 0.44)`:

```text
Plus, not minus: _light points at the star, so the star is that way. The
sign matters more than it looks — with it wrong, every world in the game
was lit from the opposite side of the frame to its own sun.
```

## Asteroids

Above `func _asteroids(r: RandomNumberGenerator) -> void:`:

```text
Rock, in three depths, along a belt rather than scattered evenly. A field
with a direction reads as an orbit you are crossing; the same rocks spread
uniformly read as noise.

The near rocks are pushed to the edges deliberately: a boulder across the
middle of the frame sits between you and what you are shooting at, and the
backdrop does not get to do that.
```

## Galactic core

Above `func _core(r: RandomNumberGenerator) -> void:`:

```text
The core of the galaxy, from inside the disc: stars too dense to resolve,
the haze they add up to, and the dust that cuts across it. The one place in
the game where the sky is bright.

Everything here follows one line — same centre, same slope — so the stars,
the glow and the lanes read as one object seen edge-on. The glow is dithered
rows rather than filled rectangles, because a rectangle of translucent
colour over a starfield is a user-interface panel whatever colour it is.
```
