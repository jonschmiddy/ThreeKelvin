The reasoning behind `tkg/scripts/ui/JumpFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Jump styles

Above `const LIFE := 0.40`:

```text
Twenty-one ways for a ship to not be here any more.

The original was one: `JumpFlare`, a vertical column of light
that opens, flashes and shuts. It is still the first entry here and still the
default. The rest exist because a jump is the most-repeated moment in the
game after a card play, and the one worth being sure about.

TWENTY OF THEM SHARE A CLOCK, and that is not a detail. `peaked` fires at
PEAK for all of those, because that is the frame the hull hides, the frame
the jump is committed, and the frame the screen swaps — see
`SectorScreen._pulse_out`. So picking between them picks a LOOK and nothing
else: none can be better or worse timed than another, and swapping one for
another cannot desynchronise anything.

`hyperdrive` is the twenty-first and the exception, because it is not an
overlay at all — it takes the hull apart. It needs its own, longer clock, and
`life()` and `peak()` exist so that everything downstream asks rather than
assumes. See MELTING below.

NOTHING WARM. `UITheme` rules that EMBER, FLARE and HOT mean something is
emitting heat, "never as decoration" — and a jump is the one bright thing in
this game that is not combustion. Everything here is drawn in the same cold
white the original column used.

Set `JumpFx.style` to choose. It is static because it is a setting rather
than a property of any one ship: four hulls jumping out of a convoy should
not jump out four different ways.
```

## Hyperdrive

Above `const MELTING: Array[StringName] = [&"hyperdrive"]`:

```text
THE ONE THAT IS NOT AN OVERLAY, and the one exception to the shared clock.

Every other style here draws over a ship that is still a ship. This one takes
the hull apart, and it spools up before it does. Jon, on the first version:
"the horizontal bar exists right as the ship is jumping... it might be nice
to have a spool up... make it dramatic." So the bar is where the charge
ARRIVES, not where it starts.

AND THEN, ON THE SECOND: "kinda cartooney". The first spool had motes of light
streaking in, a pulsing square at the middle, a fat halo, a jittering hull and
a spark that was a perfect ring of twelve identical dots -- each a charge-up
convention, and together a drawing of power rather than power. What survived
is what reads as physics: a hot line along the hull's own centre, crackle ON
the line rather than things flying AT it, a tremor only at the very end, and
a spark that is thrown rather than drawn.

Which is why `melts()` exists: the caller asks whether a style wants the hull
dismantled rather than hidden, instead of checking for a name.
```

## Hyperdrive timing

Above `const HYPER_REV := 0.25`:

```text
THE WHOLE CHOREOGRAPHY, IN SECONDS, AND THE SOUND READS IT.
`audio/hyperjump.py` parses CHARGE_S, SNAP_S, ZIP_S and SPARK_S, builds the
sound on them, and refuses to render if the sound no longer fits them. Change
one and re-run that script -- the same rule as FLAMEOUTS, for the same reason.

HYPER_REV is a held moment before any of it, counted from `depart()`. It was
half a second of engines lit, and with no thrusters on ("the thrusters
shouldn't be on") half a second of nothing is dead air, not a build.
CHARGE_S was 1.60 and is longer at Jon's ask: the spool is the part to savour.

THEN THE SOUND SET IT. The start-up is one recording, turbine-2, and it builds
to its loudest 3.8 s in -- the frame the hull goes -- so CHARGE_S is 3.80.
`audio/hyperjump.py` measures where that take tops out and will not render if
CHARGE_S has moved away from it.

HANDOFF_S is where the picture changes gear: before it the seam only creeps,
to RUMBLE_C; after it the build, the crackle and the tremor come in. It was
set for a second take that came in at 1.80 s. turbine-2 has swelled to its
plateau by about then, so it stayed; the sound no longer reads it.
```

Above `const PEAK_INTO_ENDING := 0.71`:

```text
Late, because the spark it ends on has to be seen before the screen swaps
behind it. The commit lands as the last of it goes out.

It was 0.97, a fraction of the WHOLE clock, which moved the swap whenever
SPARK_S changed: with the glint made three times faster, 0.97 would have cut to
the next system a fifth of the way through it. So it is stated as how far into
the ending the swap falls, which is what 0.97 meant when SPARK_S was 0.50.
```

## Jump endings

Above `const ENDINGS: Array[StringName] = [`:

```text
WHAT IS LEFT WHERE THE BEAM ARRIVES, on the last SPARK_S of the clock.

It was a spray of sparks and before that a ring of them, and Jon's word for
the spray was "silly". A small thing seen at the end of every jump is worth
choosing rather than guessing, so there are twenty, and `ending` picks one.
They all live inside the same SPARK_S, so which one plays cannot move the
frame the jump commits on. `spray` is the one that was there, kept last so the
others can be judged against it.
```

## Spool effects

Above `const SPOOLS: Array[StringName] = [`:

```text
WHAT THE HULL DOES AS THE SPOOL STARTS. Jon: "can we have some visual effects
happening to the ship as the spool is starting?" So there are ten, and `spool`
picks, like `bar` and `ending`. `ShipView` draws them onto the hull's own
pixels -- whole pixels, cold light only, nothing scaled -- from `spool_amount()`
pushed in every frame on this clock, the same way the melt is. `none` is the
jump as it was, kept first.
```

## Hyperdrive draw

Inside `_draw()`, above `var s := _secs()`:

```text
CHARGE, SNAP, RUN, SPARK -- on this style's own clock, in seconds.
`ShipView` holds station and renders what `ShipSlot` tells it from
`melt_amount` and `shake_amount`; everything that travels is here.

The box is the hull's opaque body (ShipSlot sizes it with
`hull_body`), so half its width is nose to centre and NOTHING here
draws the line wider than that. The run is the only thing that goes
past the nose, and it gets shorter as it goes.
```

## Hyperdrive charge

Above `func _charge(s: float, cx: float, cy: float, hw: float) -> void:`:

```text
THE CHARGE. The bar is where this arrives, not where it starts.

RESTRAINED ON PURPOSE; see MELTING for what came out and why. A hot line along
the hull's own centre lengthens to the ship's ends and never past them, and
brightens in a shimmer rather than a blink. Once it has filled out, single
points of light crackle on it -- on it, not flying at it.
```

## Hyperdrive bar

Above `func _beam(x0: float, x1: float, y: float, k: float, g: float, s: float,`:

```text
THE BAR. One function for every horizontal run of light in the hyperdrive,
wearing whichever of BARS is set.

`k` is how bright (0..1). `g` is how grown into itself it is: 0 at the first
flicker of the charge, 1 from the snap on, so the looks that assemble -- the
twisting strands, the closing dashes, the compressing layers -- are finished
by the time the hull goes. `s` is the clock in seconds, for the ones that move.

`run` is how far the beam has got through the run, 0 until it leaves the ship.
ONLY THE SPINDLE SHAPES READ IT. Jon, on spindle + ion: "i don't like how
spindle ion ends" -- the swell was worked out over whatever length the beam
still had, so a beam closing up to a point kept its full belly and flew off
as a fat coloured lozenge that stubbed into the glint. Now the swell
discharges as it runs and arrives as a fine line. It is not folded into `g`,
because the strands, the dashes and the stacked bars assemble on `g` and
would come apart again mid-run if it fell.
Nothing here draws outside x0..x1.
```

Above `func _blend(x0: float, x1: float, y: float, k: float, g: float,`:

```text
THE BLENDS, one pixel column at a time, out of four switches:

  spindle   the core thickens toward the middle of the hull
  ion       a cyan row above the core and a violet row below it
  halo      a stepped glow outside all of that, fading over a few rows
  scan      every other row dimmed, core and halo both, like scanlines
  tint      the halo takes ion's colours instead of plain cold white

Column by column because spindle changes the shape along the length, and the
edges and the halo have to follow the shape rather than sit on a straight line.
```
