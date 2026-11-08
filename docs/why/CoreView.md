The reasoning behind `tkg/scripts/ui/sysmap/CoreView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core view

Above `signal traced`:

```text
THE CORE ON THE SYSTEM MAP: the supermassive black hole Jon picked, with
all five of its motions -- the gas swirling faster in close, clumps of it
spiralling in and gone behind the hole, the glow breathing, a star circling
and being eaten with its stream hidden round the far side, and the map
behind it bent into arcs. A port of the mockup's `coreDraw`, `coreLens`,
`coreGlow` and its BH renderer (`sysmap/template.html`, the page built as
`sysmap/page/index.html`), with the map's settings: hole 15, disc to 110,
tilted 0.38 like the orbits.

Put it at the hole's centre, in whole game pixels, call `setup()` once and
`step(t)` every frame. It draws nothing until `setup()` has traced the light
(one frame of GPU work, awaited; `ready_to_draw` and the `traced` signal say
when). Two layers:
  * `lens` -- the map behind bent round the hole. It reads the screen, so it
    must come AFTER whatever it bends (the sky, the far worlds) and BEFORE
    the hole. It is this node's first child, so by default it is drawn just
    before the hole; a screen that wants it elsewhere can `take_lens()` and
    put it anywhere in its own draw order. A taken lens is moved to this
    node's position by `set_zoom()` and `step()`, so it follows a pan.
  * the hole itself (`core_hole.gdshader`): the disc and its light, laid on
    as light added to what is behind, the shadow opaque.

ZOOM (`set_zoom(k)`, 1 to 4, every frame while the map's zoom eases): the
hole is drawn again k times bigger in single game pixels -- hole, photon
ring, disc and its streaks, clumps, the eaten star and its stream, glow and
lens all k times the size, never the picture stretched. The light's paths
are traced for one size at a time, so:
  * the lens is worked out per pixel each frame, so it is always at k;
  * the hole draws the nearest trace it has, stretched by k / that trace's k
    (the hole's own ColorRect is scaled, never this node), for a moment
    soft or stepped;
  * once k has held still SETTLE seconds, the light is traced again at k
    (one GPU frame and a read back) and the hole drawn from it, sharp.
Traces are kept, one per ZOOM_BIN of k, shared by every Core, up to
CACHE_BYTES; going back to a zoom already traced is instant.

The mockup draws all of it between the worlds behind the hole and the
worlds in front of it, so that is where this node belongs.
```
