The reasoning behind `tkg/scripts/ui/ShipBreakup.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ship breakup design

Above `signal broke(strength: float)`:

```text
A SHIP COMING APART, cut out of whatever picture the ship is.

Jon (Oct 13): "Also can we do death animations?" -- for enemy ships. The
enemy art is being replaced by kept PixelLab sprites while this is written,
so nothing here may know what a ship looks like: it is handed the ship's own
pixels (`EnemyArt`'s canvas, or any sprite) and cuts them up itself.

THE CUT. A few large chunks (the "majors") split along jagged cracks -- a
Voronoi of seeds spread along the hull, its boundaries roughened by value
noise so a crack never runs straight -- and a band of shards along each crack,
carved out of the majors and cut small. The shards are what flies; the majors
drift a few pixels apart and STAY: their resting places are the wreck you
loot, so the last frame of this and `wreck_image` are the same picture.

LIGHT AS LIGHT (memory draw-light-as-light). The glow along the cracks is not
a coloured outline: each major carries a light map built from its own crack
pixels -- a white-hot core, falloff over five pixels, the outer steps
dithered 2x2 -- drawn ADDITIVELY and cooled from white through orange to red
by multiplying its colour. Its strength is stepped and eased, never sampled
from noise, so it cannot flicker.

WHOLE PIXELS. Positions round; a shard tumbles in quarter turns, which are the
only rotations pixel art survives without shimmering (turn-pixel-art-in-
whole-pixel-steps); a major never turns at all.

SOUND FOLLOWS WHAT YOU SEE. `broke` fires on the frame a break becomes
visible, with how big it is; the screen plays the explosion there. Nothing
here plays a sound itself, so a harness can film it silent.

TEN MORE (Oct 13). Jon on A, B and C: "these death animations are sick as
FUCK ... Can you create like 10 more". D to M are each a different IDEA, not
a re-timing: a reactor breach, a chain of blasts, an engine overload, a
decompression, a beam slice, a disintegration, a collapse into a singularity,
a shield popping first, a melt, a crumple. They share A-C's rules and add:
  - SPACE, NOT EARTH. Nothing rises like smoke or falls "down": debris and
    gas drift and tumble, embers leave a crack outward. (A-C's shards settle
    a pixel or two downward; the new ones never do.)
  - Each one's cut is its own (`_cut_new`): wedges round a hole for a breach,
    one straight line for a slice, folds for a crumple, a front for a
    disintegration. MELT and CRUMPLE deform the hull first, in a few held
    steps, and are cut from the deformed picture, so the wreck is deformed.
  - `moment` names every visible event a sound can follow (a pop, a hiss
    that lasts, a crunch), with its length; `broke` still fires on the
    explosive ones. `SOUND` lists them per style.
  - The last frame is `wreck_image` exactly (`rest_image` proves it), with
    nothing of light left over: every glow and mote is out before the end.
```

## Setup off thread

Above `func setup(img: Image, used: Rect2i, origin: Vector2, the_style: int, seed: int,`:

```text
`img` is the ship's whole canvas; `used` the ship's box in it (EnemyArt's
`used_rect`, or the sprite's ink); `origin` where the canvas's top-left sits
in this control's space. Same `seed`, same cut -- see `wreck_image`.
ON A WORKER THREAD (`SectorScreen._prebuild_death`, `ShipLoss.prebuild`)
this is pure CPU work: the node is made on the main thread, its textures are
owed (`OffThread`), and its settings and layers wait for `finish`, which the
main thread calls once the worker is done. On the main thread it finishes
itself.
```

## Partition

Above `static func cut(img: Image, used: Rect2i, seed: int, is_boss: bool = false,`:

```text
THE PARTITION, as data, deterministic in `seed`. Static so the wreck on
LOCAL can be drawn from the same cut long after the animation is gone.
  majors: [{image, at (Vector2i), off (Vector2i final drift), crack (PackedVector2Array local)}]
  shards: [{image, at}]
  centre: Vector2i
D-M cut their own way (`_cut_new`); A-C's cut is untouched.
```

## Melt and crumple

Above `static func _melt_pic(H: Dictionary, seed: int, k: float, given: Dictionary = {}) -> Dictionary:`:

```text
MELT at `k` (0 whole, 1 slumped): the hull goes soft. Every pixel is fetched
from a little further out and a little aside, so the hull draws in toward its
own middle line and its outline wanders; the far edges (fins, guns) wander
most. Thin parts with fewer than two neighbours run off, pass by pass -- those
are the drips. Then the colours run together. Deterministic in `seed`, so the
film's steps and the wreck agree.
```

Above `static func _crumple_pic(H: Dictionary, seed: int, k: float) -> Dictionary:`:

```text
CRUMPLE at `k`: two or three fold lines across the hull; the segments
between them are shoved toward the middle, kicked up and down in turn and
sheared, so the plates stair-step like bent metal. Each fold gets a dark
crease on one side and a lit ridge on the other, and each segment a buckle
down its middle. Returns which segment every pixel landed in, for the cut.
```

## Light rings

Above `func _draw_ring(ci: CanvasItem, c: Vector2, r: int, squash: float, lvl: float, col: Color,`:

```text
A ring of light in whole pixels: a one-pixel core, a dithered pixel either
side. `squash` < 1 lays it flat, a shock front seen near edge-on.
`trail`: how far it moved since the last frame. That stretch behind the
front is lit too, falling off, so a fast ring is a travelling band and not a
thin line lit for one frame at each place (which reads as strobing: the
flip-back count halved with it).
```

## Creature deaths

Above `const SPORE: Array[Color] = [Color("#e2fff2"), Color("#97f0c9"), Color("#45b88f"), Color("#1d6650")]`:

```text

Jon (Oct 13): the Voidwhale Calf and the Void Leviathan get "a more natural
death animation that's different from the ships". No metal: nothing cracks
white, nothing flies off in shards, no fire. Something living dying in space:
its own lights go out, it curls, it blooms spores, it parts at its segments.
Its glow is its OWN pixels (the warm, saturated, bright ones -- 7% of the
calf, 3% of the Leviathan): the body is drawn with them dark, and the light
layer gives them back as gathered light (the pixel, a halo brighter where
they crowd, dithered at its edge), so "going out" is the light stepping down,
never a colour swap.
```

## Boss set pieces

Above `const BOSS_HOOKS := [&"shake", &"slowmo", &"flash", &"duck", &"stinger"]`:

```text

Jon (Oct 13): "The custodian (and hellbender) these need ACTUAL epic death
sequences." A boss's death is its own set piece, 7-8 s in phases, not the
ship styles' burst run. Three for each:
  THE CUSTODIAN (glass octahedra on a spine, orange pinpoint lights, a core)
    C1 CASCADE    the facets crack one by one along the spine, each spilling a
                  beam of white light; the core swells; everything is pulled
                  in; a white blast and a shock ring; glass shards rain out
                  and cool.
    C2 UNMAKING   it loses cohesion: the facets drift apart on the spine, the
                  lights go out one by one, then each facet shatters in turn,
                  in slow motion, glass glinting as it turns.
    C3 SUPERNOVA  a rising whine, the core white-hot through the glass until
                  the whole body glows, a flash that fills the enemy's half,
                  a dark ring, and the body left charred and smoking.
  THE HELLBENDER (a rival harvester, its holds glowing with what it took)
    H1 CHAIN      reactor alarms strobing, blasts marching through the hull,
                  the holds rupturing and spilling glowing stolen cargo, then
                  the main reactor: the hull splits in two.
    H2 BURN-OUT   fire spreads from the salamander device, which glows
                  red-hot; blasts walk through it; it lists (nose down, in
                  whole-pixel slices) and breaks apart trailing fire.
    H3 UNCOIL     (ours) the stolen light breaks out ring by ring: its ribs
                  light gold from the hold outward, the hull stretches apart
                  rib from rib, and the light bursts out, leaving a husk.

The same rules as every death: pieces move in whole pixels (cut, never
turned), light is drawn as light, nothing rises or falls, and the last frame
is `wreck_image` exactly. Each piece's way to its rest is keyframed
(`keys`), its picture changes at set times (`stage_t`), and the lights,
beams, spheres, rings and emitters are data the clock plays.

SCREEN HOOKS, AS MOMENTS (nothing here moves the screen): `shake` (s = px,
length), `slowmo` (s = clock scale, length in screen time), `flash` (s =
white's peak over the whole screen, length), `duck` (s = how far the music
drops, length), `stinger` (a music hit). The harness applies them so the film
shows the whole effect; SectorScreen can do the same later.
```

## Custodian variants

Above `func _plan_c1(order: Array, core: Vector2, cs: Vector2) -> void:`:

```text
Jon picked C1, centred, with "some variants of the explosion and how the
ship falls apart". All three open the same way -- the facets crack one by
one along the spine, each shooting a beam, while a ball of light swells at
the true centre -- and end differently:
  C1a SHATTER OUTWARD  a white blast; the facets fly out and slow into the
                       wreck; big glass shards tumble out, glinting.
  C1b COLLAPSE INWARD  the cluster crushed in on its centre, then a ring of
                       light blows the pieces out in layers, outer first.
  C1c SPLIT            a blast that runs along the spine from the centre to
                       both ends; the guardian breaks in half, glass shedding.
```

## Rib seams

Above `static func _rib_curves(H: Dictionary) -> Array:`:

```text
H3's rib seams, traced off the picture: the luminance smoothed down each
column (the ribs run near vertical, so this keeps the seams and loses the
plating's grain), its dips along each row, and the dips linked row to row
from the middle outward into curves. A curve that does not reach half the
hull's height there is grain, not a seam. Each curve: `traced` (its x per
row, -1 where it was not found) and `full` (carried on to every row, so a
cut runs the whole height).
```
