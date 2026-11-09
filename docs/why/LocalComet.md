The reasoning behind `tkg/scripts/ui/LocalComet.gd`; each heading is referenced from the code by a `Why:` line.

## On the band

Above `extends Node2D`:

```text
LOCAL lays the system's worlds out on its band from where the map has them
(`LocalSky._step_worlds`). The comet goes on the band the same way, so it is
in the sky where it truly is: "it must make sense where it stands". It is drawn
as the map draws it (`SkyWeather.Comet`): a white head and coma, a straight
blue ion tail and a curved warm dust tail, in 2x2 blocks on the sky's grid.

It is held at the clock LOCAL holds (`LocalSky._tm`). The map's clock does not
run while LOCAL is up (PairLocalTest), so a comet that moved on in LOCAL would
jump back on the map. The worlds' slow drift on the band hides that; a comet
crossing the system in about a minute would not.

It is drawn by the map's own painter (`SkyWeather.RealComet.paint`), so the
two always look alike.

The comet up close (a nucleus with LocalFx's lit tails, as `the_comet` draws
one) belongs to Phase 13's catch, when the ship waits on its path and it goes
by. That is part 5 of the build.
```

## Size

Above `const K_NEAR := 1.25`:

```text
Jon, Nov 9 ("K3"): the first band comet, about 20 px, was too small for
something you chase. It is now the map's look at 1.0 to 1.25 times its size
(K_FAR far from the star, K_NEAR at it): an ion tail of about 60 to 70 px and a
gold dust tail of about 60 to 80 px. That is a real presence in the sky and
still a quarter of the ship's length.

It is drawn over the band's worlds and suns. When it passes behind the star on
the band it is not hidden by the disc: the band is nearly edge on (TILT 0.07),
so that lasts a moment of a pass that LOCAL holds still anyway.
```

## The close pass

Above `const PASS_D: Array[float] = ...`:

```text
Jon (Nov 9): "Shouldn't we have the ship like right next to the comet... like
it's approaching close to do science?" Met on its path, the comet comes in from
the right over ARRIVE_S, holds beside the ship while its reading is open, and
goes out to the left over LEAVE_S once the reading is taken.

It holds off the ship's nose toward the star (PASS_D), so its tails, which
point away from the star, stream back over the ship, and the nose sits inside
the edge of its coma. Nearer spots are closer, bigger and rougher: the coma
92, 118 and 142 px, the nucleus 18, 22 and 28 px, and grit in the tail at the
near spot (36 grains) and at the star (80). At the star the heat shows round
the star's side of the view.

The coma and both tails are light in dithered steps, and the nucleus is dirty
ice lit from the star with a dithered edge. They are painted once per pass into
a picture at the sky's own half size, so each pixel is one of its 2x2 blocks.
Drawn block by block every frame they were tens of thousands of rects. The
tails' way is taken from where the head holds, not where it first shows: taken
mid-arrival they pointed away from the ship.
```
