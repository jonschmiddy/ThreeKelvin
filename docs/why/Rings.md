The reasoning behind `tkg/scripts/ui/planets/Rings.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ring looks

Above `enum Look { DOTS, ICY, DUSTY, DARK }`:

```text
A WORLD'S RINGS ACROSS THEIR WIDTH: how thick and how bright the ring is at
each distance from the world's centre, rolled from the world's seed, as one
strip of texture `planet_ring.gdshader` draws the ring from and
`planet.gdshader` reads to lay the ring's shadow across the world.

Three looks, for Jon to pick from (Jon: "can these rings be a bit nicer?
they're flat"):
  ICY    -- bright and many-ringed, Saturn's: a faint inner sheet, a broad
            dense ring, a clear dark gap, an outer ring with a thin gap of
            its own, and a narrow ring outside it all.
  DUSTY  -- two or three broad soft bands with a soft trough between, and a
            thin haze reaching out past them; thick enough that the world's
            shadow cuts a black notch out of them.
  DARK   -- Uranus's: a handful of thin dark rings and one bright one.

THE GAP HAS TO SHOW. A real gap is a hair wide; on the map a world's ring is
ten blocks across, and a gap thinner than a block averages away into a slightly
dimmer ring. So every feature here is at least `px` wide, `px` being how far
one block of the picture reaches across the ring at the world's size: the
gap stays a dark line a block wide however small the world is drawn, and the
dark rings stay a block wide with a block between them, or are left out.
```

## Ring strip

Above `static func build(look: int, world: StringName, seed: int, px: float) -> Dictionary:`:

```text
A world's rings in look `look`, at `px` (one block's width, in world radii).
Returns {tex, rin, rout, ramp_a, ramp_b, cast, dark_shadow}: the strip
(red: how much of the light the ring stops; green: how bright its stuff is;
blue: 1 where it is drawn in the second, dark ramp), the ring's inner and outer
edge in world radii, its two ramps, how dark its shadow on the world is, and
how dark the world's shadow on it.
```
