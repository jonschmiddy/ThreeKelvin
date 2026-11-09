The reasoning behind `tkg/scripts/sim/TwinDrawTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Twin map checks

Above `const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
TWO SUNS AND HEAVY GIANTS ON THE MAP (ruling 20, Oct 30), measured headless:
  godot --headless --path . -- sheet=TwinDrawTest [seeds=24] [views=N]
Every check here looks at twins it has counted and prints how many, so none
passes on an empty set.

  * THE TWIN SUN FLOOR (`SystemView.twin_floor_on`): in every twin of
    `seeds` seeds (24, the layout reviewers', under twin=all), with a fetch, a
    hunt, the Hellbender and all three put out past its edge as
    `SystemTest._comers` puts them, the map opens below the layout's
    `fit_zoom` -- and there each sun's drawn plane radius never passes the
    one it has at the fit (its true size and its held disc, at the opening
    zoom and at 12 zooms from there to the fit), no star's close ring runs
    inside its drawn sun, and the worlds round each star are counted against
    their suns, before (the old floor, `SystemLayout.sun_drawn`) and after;
  * THE PAIR TURNS (ruling 23): every check of the drawn map below at
    `PHASES` (8) angles round the pair's lap, not only the one it was laid
    out at;
  * THE DEPTH ORDER (`SystemView.step`): over the twins of the four
    systemtest seeds as rolled, each world round a star drawn after its sun
    when it is nearer the viewer than the sun and before it when farther, at
    24 moments round its year, for both stars; the nearer of the two suns
    drawn over the farther ("stacked:A"), and each sun drawn where the pair
    has it (`star_screen`);
  * THE ORBITS ROUND THEIR OWN CENTRES (`_Lines.orbit_runs`): every point of
    every drawn ring on some body's ring about its own host, and each world
    round a star with points on its own;
  * THE LIGHT: each world round one star of a pair lit from that star (the
    share of its light, the angle of its one light against the way to it);
  * THE SHIP ON A WORLD'S 20 px RING (`ShipFlight.orbit_r`), measured, not
    judged: how much of its ride round a world circling one star its centre
    spends inside the world's drawn disc, at the opening zoom and at 1 (since
    Jon's "ring:A", Nov 1, it is drawn over that world in a light outline
    there: TwinSiteTest checks that on the real map);
  * THE SUN FLOOR AS DRAWN (Oct 31): the same promise read off the map
    itself, each SunView's own disc and corona (`_kd`, `_k`) as `step` sets
    them, on every frame of a zoom out from the fit to 0.6 of it and of the
    jumps and settles after, for both stars -- the floor above is the
    layout's sums, which hold by construction and could not catch the map
    dropping its cap;
  * THE NEAR POINT'S RING AND MOONS (Oct 31): every drawn orbit point inside
    a star's hole on screen is in front of that star (none behind it), some
    are (a world round one star of a pair passes in front of its sun, and its
    ring's near half with it), and a world in front of its sun inside its
    hole keeps its moons (`_Moons.positions`), one behind it does not;
  * LOCAL'S TWO SUNS, as far as headless reaches (`LocalSky._build` stops
    before any picture is made, so the suns, their slots, the disc cut, the
    palette and the steps run first in a window): with the ship parked at a
    world round each star and at each star's close orbit (a close pair, with
    no world round one star, at each star's close orbit), the place kept
    (-4 too), the lit sun the near one, the distance from it (a world round B
    65 to 100 px out, not 350), the near sun drawn the bigger, the two discs
    apart on the band, and the cloud's bubble round the lit sun clear of
    every band of distance from it that a body sweeps.
Prints `twindrawtest: PASS` or `twindrawtest: N FAILURES`.
```

## Floor seed

Inside `_floor_seed()`, above `var n_opt := n.options.size()`:

```text
(counted once the options are rolled: `SystemLayout.of` rolls them on a
node's first layout, and counted before, the first case's cut back to
that count wiped them and every later case was laid out bare of them)
```

## Phases

Above `const PHASES := 8`:

```text
How many angles round its lap each pair is drawn at, and how many moments of
each world's year at each angle but the first (which has all 24): the map is
stepped once a moment, and 24 at every angle, with the orbit lines read at
every one, took the sheet from 110 s to 390.
```

## Star holes

Inside `_phase_checks()`, above `var zq: float = (q.y - (float(SystemViewS.CY) + float(view.pan.y))) / (SystemViewS.TILT * float(view.zoom))`:

```text
A STAR'S HOLE ONLY BEHIND IT: a point drawn inside a star's hole is in
front of that star. (The point's z on the plane from its screen row:
whole pixels, so half a pixel either way, and points within a pixel
of the star's own depth are not judged. And the hole a pixel smaller:
`orbit_runs` cuts by the point before it is rounded to its pixel,
which moves it up to 0.71 px -- judged by the rounded point, 28 of
3,750 drawn just outside the hole's edge read as inside it.)
```

## Sun floor

Above `func _view_floor(view, at: String) -> void:`:

```text
THE SUN FLOOR AS THE MAP DRAWS IT: from the fit, still, a zoom out over 24
frames to 0.6 of the fit, then jumps to 0.683 (the worst comer's), 0.8 and
0.95 of it, each held until it has settled and 20 frames on -- on every
frame, each sun's disc and corona as its own SunView has them (`_kd`, `_k`),
in plane px, never wider than the layout's sun at the fit: the disc than the
most it is held at there (`SystemLayout.held_most`), the corona than that or
its true size there, whichever is more (the corona is the true size while the
zoom moves and eases onto the disc once it is still). Counted in frames, never
the clock: `step` measures its settle in its own frame steps.
```

## Painted

Above `func _painted() -> void:`:

```text
PAINTED'S SILHOUETTES FACE THE LIGHT THE CLOUD IS LIT BY (Nov 1; they faced
star A alone, "SectorPainted's rims face star A only"): its paint pass
(`sector_b_paint`) outlines the cloud where it meets the sky, a rim on the
side toward the light and an outline on the side away. The other styles light
that cloud by both suns (`sky_nebula`'s `light_at`), and each world by its own
one light (checked above for every style: `toward_light_of`, which the world's
shader takes in PAINTED too). Headless compiles no shader, so this reads the
numbers each pass is given: in a twin the paint pass gets star B's place on
screen, its brightness and the light's reach, the same as the cloud's; with
one sun it gets none of them, and its shader keeps its defaults (star B's
brightness 0: star A's way alone, worked out as before). And a moon's
brightest step is warmed by its own world's light (`tint_at`), as the world's
is; with one sun by the star's, as before.
```

Inside `_painted()`, above `var nm: ShaderMaterial = view._neb_mat`:

```text
THE CLOUD'S OWN LIGHT, as `sky_nebula` is given it this frame: star B's
place (the cloud's unrounded, the silhouettes' its disc's, within the
2 px block), the light's reach from its own lzoom, home_zoom and lscale,
and star B's brightness where it has it (headless the sky's bake, which
gives it `star2_light_k`, is skipped: the same call then). A clear sky
has no cloud: the view's own numbers.
```
