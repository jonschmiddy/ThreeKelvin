The reasoning behind `tkg/scripts/ui/sysmap/SunView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sun view

Above `const SHADER := preload("res://shaders/sun.gdshader")`:

```text
A SYSTEM'S SUN ON THE MAP: the ordinary, red and blue suns, as the approved
mockup paints them ("Twenty-Four Stars", Jon: "These are great. Bang.
Done."; sealed as `ST` in the scratchpad's `sysmap/page/index.html`). Put it
at the star's centre in whole game pixels, `setup` it once per system and
`step` it every frame with the map's clock.

The picture is `sun.gdshader`, one pass over the mockup's 420x300 box round
the star. This script does the parts of the mockup that are a handful of
numbers a frame rather than a picture: the roll of the system's looks, where
each plume and sunspot group is in its life, the corona's puffs, the sparks
off an ember star, and the flares -- their kind, their loop or bubble, and the
pixels they splat. Those go to the shader as uniforms and as one small float
texture (`_data`, rows described in the shader's header).

Like the mockup, the star is redrawn only when the clock has moved 0.03 s
since the last drawing (`starLook`'s `STAR_C.last`): at 60 frames a second
it moves at 30, which is how its motion was approved.

ZOOMED (`set_zoom`), the same star is drawn k times bigger by the shader,
in single game pixels: everything rolled and listed here stays in the
mockup's 420x300 box, and only the box drawn on the map grows.
```

Above `func setup(kind: String, system_index: int, star_r: float, second: bool = false) -> void:`:

```text
Which kind of sun ("ORDINARY", "RED" or "BLUE"), for which system, at what
radius in game pixels -- the map's `starLook`: seed index * 7 + 3, radius 16,
48 or 24.
`second`: A PAIR'S SECOND SUN (ruling 20, Oct 30), star B of a twin: its looks
rolled from a seed of its own (index * 7 + 5, which no system's star A has),
and warmer -- the lighter star of a pair is the cooler, an orange dwarf
beside a yellow one. Its face sits WARM_B of the way up its ramp (white-hot
at the middle goes to amber, the limb to deep orange), and its glow leans
orange (GLOW_B). The same shader and palette as star A's: nothing new to
compile.
```

## Sun zoom

Above `static var k_max := 9.0`:

```text
AS FAR AS THE MAP EVER ZOOMS: the wheel stops at 4, but the dive into LOCAL
(`SystemMapScreen.ladder_cam_begin`, seam 2C) carries the map on to 9 while
the world grows into LOCAL's. Held at 4, the sun stopped growing there and
shrank against everything round it for the rest of the dive (and stood at 4
while the map shrank back past it on the way out).
(a static var only so a harness can film the old cap, 4, beside it)
```

Above `func set_zoom(k: float, k_disc: float = -1.0) -> void:`:

```text
THE MAP'S ZOOM, 0.1 to `k_max`: the star drawn k times its size -- its radius, its
cells, its plumes and flares, its glow and the box round it -- by its own
shader, in single game pixels; the same rolled star, nothing re-rolled. Below
1 since the system grew three times wider and opens zoomed out to show it all
(`SystemView.star_k` keeps it a few pixels of disc at the least).
Cheap enough to call every frame while the zoom eases.

`k_disc` (the sector map, while its zoom moves): the disc's own size, held in
whole blocks of radius, while `k` is the true zoom the corona, the glow and
the prominences are drawn at (`sun.gdshader` `limb_k`). Left out, both are k.
```
