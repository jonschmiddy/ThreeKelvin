The reasoning behind `tkg/scripts/ui/sysmap/SkyBake.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## System sky

Above `const BAKE := preload("res://shaders/sky_bake.gdshader")`:

```text
THE SYSTEM'S SKY, worked out once per system: its own nebula, thousands of
stars, the star's light on the space round it, the shafts through the dust.
A port of the approved mockup's `bakeLook` (scratchpad `sysmap/template.html`)
for the look Jon picked: Sky C "its own nebula", Light B "shafts and shadows,
gentle", the nebula's detail as it was ("the detail is perfect now"), drawn
in 2x2 blocks for the chunky pixel palette.

Two pictures come out of it, both made by `sky_bake.gdshader` in one pass
each through a SubViewport:
  * `base`: the sky WITHOUT the gas -- void, stars, the star's glow and
    shafts, darkened where dust lies in front;
  * `gas`: what the gas adds to each pixel (RGB), so `sky.gdshader` can roll
    slow waves of brightness through it every frame (the gas drifting), and,
    round a pulsar, how much gas there is (A), for the beam to light.
The stars are placed here, from the mockup's own generator in its order of
draws, so a system's sky is its sky in the mockup.
```

## Star cache

Above `static var _stars_kept := {}`:

```text
THE STARS LAID OUT ONCE A SYSTEM (Jon on 2C: "still has a small delay/hitch"):
the few thousand stars are placed by noise worked out a star at a time, about
a tenth of a second of one frame, and a map is built new every visit -- the
way back out of LOCAL built it again for the system it had just shown. The
same system always places the same stars, so they are kept for the session
(key -> [stars texture, twinkle list]), the last few systems.
```

## Sky by location

Above `static func look_for(n: MapGen.MapNode, kind: String) -> Dictionary:`:

```text
THE SKY BY WHERE THE SYSTEM IS (Jon: "Maybe we can have the sectors that are
in a nebula have all the clouds, and the sectors that aren't in a nebula have
something more simple"). Inside a cloud the gas is the cloud's own, in its
kind's colours, as the star chart paints it; outside one the sky is clear --
stars, a faint distant band of the galaxy, a little thin dust. A pulsar and
the core keep their own skies.
```

## Cloud field

Above `const FIELD := preload("res://shaders/sky_field.gdshader")`:

```text
THE CLOUD SEEN FROM INSIDE, BAKED (SIMPLIFIED, direction C: `field`): its
density, its billows and far gas, and their gradients, one texel a 2x2 block
of the sky with FIELD_MB blocks of margin for the slide and the flow, for
`sky_nebula.gdshader` to light and stream every frame -- and on the right
FIELD_MR, for the map's cloud drawn on past its picture's end (`SystemView`
`_past`, to sky px 1120). (Every reader takes FIELD_MB as the margin on the
left and the top, and the width as FIELD_W: the extra on the right only
adds sky there.)
```

## Cloud pillars

Above `static func em_pillars(sd: float, cc: Vector2) -> Array:`:

```text
THE PILLARS of an emission (or reflection) cloud, rising toward its sun
(C: dark columns with shoulders and knotted heads, their star-facing rims
lit): four to six, most from the dust bank below the star, each [base, tip,
width at the base, width at the head, its own seed], in sky pixels. Worked
out here and handed to the bake, so the weather knows where the tips are
(a jet leaves one) without guessing from the picture.
```

## Sky stars

Inside `_lay_stars()`, above `if float(look.get("band", 0.0)) > 0.0 and float(look.get("band_glow", 0.06)) <= 0.0:`:

```text
NO SPIKES on the brightest any more (Jon: "these stars in the sector
view are weird"): a spiked star is a distant supernova now, and comes and
goes (`SystemView._Nova`). Nothing here drew from R, so every other star
is where it was.
THE GALAXY'S BAND IN A CLEAR SKY (SIMPLIFIED): a crowd of faint stars along
it, thickest on its line, instead of a glow (drawn after every other star,
so those are where they were)
```
