The reasoning behind `tkg/scripts/sim/OneHoleTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## One hole

Above `var _fails := 0`:

```text
ONE BLACK HOLE AT THE CORE, ONE PULSAR AT A PULSAR, headless:
  godot --headless --path . -- sheet=OneHoleTest
Jon, Oct 13, at the core: "why are there two black holes lololool". LOCAL's
sky draws the system's own star -- the core's hole (`CoreLegacy`, the hole
every style shares) and a pulsar with its beams -- and the encounter's place
picture (`EncounterView.AreaView`) drew it a second time beside your ship.
For several galaxies: at the core and at every pulsar the place picture is
empty while the sky's star is that star; every other kind of system keeps
its place picture (a station, a beacon, a battlefield, a derelict). Then the
real LOCAL at the core in every look of its hole (`LocalSky.core_look`): drawn
once, centred, its black shadow whole between the HUD and the bottom strip
(the large look's whole disc too; the huge look's glow runs off on purpose,
the high ones' off the top).
```
