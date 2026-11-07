The reasoning behind `tkg/scripts/ui/LocalLife.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Local life

Above `const AIR := preload("res://shaders/local_air.gdshader")`:

```text
LOCAL'S LIFE (Oct 11, the magnificent pass; Jon kept these four of five):
  * THE AIR of the world you orbit, a thin bright shell on its sunward limb
    (`local_air.gdshader`);
  * ITS CITY LIGHTS, when the system is settled and the world has dry
    ground: its towns on the night side, clusters of points of light
    (`local_night.gdshader`);
  * ITS MOONS GO ROUND it, in front of its face and behind it, their eclipses
    on its face -- but only while nothing is staged in its sky (below);
  * FAR TRAFFIC in a settled system, tiny ships crossing along its plane.
(A fifth, the star's light on your hull, was cut: Jon, Oct 11.)

IN EVERY STYLE, each in its own hand (as the dust is, `LocalDust`):
SIMPLIFIED dithered steps; PAINTED flat hand-picked tones, no soft glow,
motion in held poses; RADIANT light through an exposure, softer and wider;
LEGACY its old blue-greys, plainer.

THE MOONS KEEP OUT OF WHAT IS STAGED (Jon: a moon must never pass over an
event's subject, a station or your ship during the dock). Two rules:
  * a moon goes round only while LOCAL is QUIET -- no event's subject up, no
    fight and no wrecks in the slots, no zoom (the cutaway, the ladder: the
    dock is a ladder move), the camera at rest -- and otherwise holds where
    it is (it eases to a stop in a fraction of a second, a block at most);
  * each moon's orbit is CHOSEN CLEAR of what always stands there -- your
    ship, and at a station its side and the corridor your ship docks along --
    from a few orbits by size, tilt and roll; a moon with no clear orbit
    stays where it always hung. And it never steps into anything staged even
    so (each step is checked against every subject piece, slot and station
    rect, and held if it would).
`-- sheet=MoonTest` checks both, headless, in the merge gate.

The traffic keeps far and sparse, above the fight in the system's band, and
is never up with an encounter: it fades out while LOCAL is not quiet, so it
can never be read as part of one.
```

## Moon shadow stepping

Inside `_draw_moons()`, above `if pos != m.get("sh_at", Vector2.INF):`:

```text
ITS SHADOW MOVES WHEN IT DOES, a block at a time, all of it: its place
and its depth held from the step the moon was drawn at until its next.
(From its true place the shadow crept a fraction of a pixel a frame;
then with its place stepped but its depth still gliding, each step
threw the shadow a block on and the glide drew it back a hair the next
frame -- a block of RADIANT's fine shading at the shadow's edge went
A, B, A at every step of every moon.)
```
