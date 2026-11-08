The reasoning behind `tkg/scripts/sim/MapPerfTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map trims

Above `const SystemViewS := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
THE SECTOR MAP'S CPU AND GPU TRIMS DRAW WHAT THEY DREW (the Mac's map, Oct 27):
  godot --headless --path . -- sheet=MapPerfTest [seeds=4242,77,1301]
  godot --path . -- sheet=MapPerfTest palcache        (needs a window)

Each trim is held to the code it replaced, through the real map:
  * THE DUST: a wisp sheet whose colour is black (a clear sky, outside LEGACY)
    is not built (`SystemView._wisps_blank`); every fluff sheet keeps the seed
    it had when the wisps were built before it (HIGH and LOW), and a cloud,
    a pulsar and the core keep all nine sheets;
  * THE ORBITS: `_Lines.orbit_runs` -- the camera read once, the points
    worked out in place, stretches off the frame skipped -- gives exactly the
    lines the old loop did (kept below, `_old_runs`, as it was), point for
    point and colour for colour, and the same with the skipping off, over
    cameras from the whole system to the closest zoom and panned past the
    frame's edges;
  * THE BELTS: each rock's draws from the belt's table are the generator's own;
  * THE LINE: `ShipFlight._run_line` with the centres worked out once a frame
    (`_centres`) is the line it was with each centre worked out where it was
    needed, from many states in every system, and it prints how long each
    took.
`palcache` (windowed): a system shown, another, the first again -- the second
visit to it cuts no palette and wears the first visit's; and a third visit with
the cache off cuts one afresh, printed against the first (how many of its
colours moved), with how long each visit took to its palette.
```

## Old orbit loop

Above `static func _old_runs(view) -> Array:`:

```text
The orbits' loop as it was before the trim (SystemView `_Lines._draw`, Oct 27
main), its draws collected instead of drawn. TWO SUNS (ruling 20, Oct 30), in
step with `orbit_runs`: each ring round its own centre (`orbit_point` already
adds `Body.host_at`), stopped at star B's disc as at star A's -- in a twin each
star's disc only where the ring is behind that star (Oct 31: a world round one
star passes in front of it) -- and its near half told by where on its own ring
a point is (its z less its centre's). A TURNING PAIR (ruling 23): each sun's
hole where the view draws it at the map's t (`star_screen`) and behind it
by its depth then (`star_depth`): star A leaves the origin, and its depth is
0 only at t 0 (one sun: the origin and 0, as ever).
```

## Line cost

Above `func _line(view, key: String) -> void:`:

```text
THE LINE from many states of the ship, with the centres shared and without;
and in the same system with two suns (ruling 20: each star a bumper with a
close ring of its own, letting go settling round the nearer star or both),
where it may have them.
The pair's cost with two suns against the same system's with one is printed
(Oct 31, after `ShipFlight` kept each star's numbers: 1.5 to 2.1 times, was
1.9 to 2.3), not judged: the Mac's load varies.
```
