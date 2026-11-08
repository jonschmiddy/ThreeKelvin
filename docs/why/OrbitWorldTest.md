The reasoning behind `tkg/scripts/sim/OrbitWorldTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Orbit world test

Above `var _fails := 0`:

```text
LOCAL SHOWS THE WORLD YOU ORBIT, BIG, FROM ITS FIRST FRAME, headless:
  godot --headless --fixed-fps 60 --path . -- sheet=OrbitWorldTest [seeds=7,11,...] [quick]
Jon, Oct 21: "Does the local view show the planet you are orbiting the first
time you go to a planet? That was an issue before. I want the planet you are
orbiting to be large in the background (you are close to it)."
Through the real doors with the ladder on (its clock stepped 1/30 s): a new
run launched onto LOCAL; then in each system visited -- the start, a jump on,
a station's -- every world flown to on the map for the first time (FLY HERE,
and GO on an event where one is) and LOCAL by the HUD's tab, Tab round the
chart, or the GO's own zoom down. On the FIRST frame LOCAL is up (or built
ahead and handed in), its sky's world is the one the ship orbits (the body,
its kind and seed), never the world before and never none; open space, the
star and a station keep no world. After SAVE & EXIT and CONTINUE, still it.
Every world drawn at least `LocalSky.near_r_min()` across its radius,
behind your ship (the sky under the scene), and clear of the HUD and the
goal line. And on every one of those LOCALs, what stands beside your ship is
what is at that place (`_scene_check`): the place picture and an event's
subject only where the event stands (an event taken keeps its subject while
you stay), and a station's side, ring and bar only at the station, also when
LOCAL is pressed as the ship burns onto its orbit.
```

## Surface memory

Above `func _mem_check(what: String, sky: LocalSky) -> void:`:

```text
ITS SURFACE'S MEMORY OVER ALL OF IT THAT CAN BE SEEN (`PlanetView.mem_clip`):
the world you orbit works its memory out only inside the near picture (much
of a giant runs off its bottom or side), so every block of the disc that
picture shows must lie inside the memory's window -- and the window must be
smaller than the whole memory when the disc runs well off the picture (past
its margin and, on the right, the lead a leaving ship's camera needs), or
the clip has stopped saving anything. Headless the sky builds no near world,
so one is stood in a near picture of its own as `_build_near` builds it, from
the same plan; the window is worked out as the frame before drawing would.
```

## Own light

Above `func _own_light_check() -> void:`:

```text
A WORLD THAT GIVES OFF LIGHT OF ITS OWN IS DRAWN FROM ITS OWN SAMPLES
(`planet.gdshader`, `own_light`): drawn from its memory, a world's screen pass
takes none of its four samples unless it is one of these -- so every kind
whose surface burns (`has_emit`), glows, glints or shows an oil slick's
colours must be on that list, or it would lose that light wherever the
memory holds it (LOCAL's world, the map's). Read off the shader's source.
```

## Scene check

Above `func _scene_check(what: String, sc: SectorScreen) -> void:`:

```text
WHAT STANDS BESIDE YOUR SHIP IS WHAT IS AT THAT PLACE (Jon, Oct 21: "This
planet has no events here, but when I orbit the planet and click LOCAL, it
has this weird signal model... Every planet in this sector has this signal"):
 - the place picture (`EncounterView.AreaView`: the beacon, the derelict, the
   battlefield) only where one of the system's events stands, and none at a
   world, the star or the edge with none;
 - the event's subject (`LocalSubject`) only at that event's own place, and
   an event over keeps its subject while you are still parked at it (the bar
   says how it went: `LocalEventDrawer.bar_option`);
 - in a station's system, the station's side, its ring and the bar's "A
   STATION HERE" all together where the ship is at the station (`Router.
   at_station`, as the map kept it), none of them anywhere else -- also when
   LOCAL was opened as the ship burned onto the station's orbit.
```

## LOCAL is GO

Above `func _local_is_go(sd: int, label: String) -> void:`:

```text
LOCAL IS GO (Jon, Oct 21: "I want to see the actual event of that
planet/POI... Clicking GO or clicking LOCAL should have the same result"): at
a world with an open event (the first open there in the map's list order),
GO from another world, then FLY HERE and the HUD's LOCAL, then FLY HERE and
Tab round the chart -- each with LOCAL's own arrival -- all end the same: that
event's band up on it, its subject drawn. NOT NOW, and LOCAL again with no
flight between leaves it closed (its subject still there); GO, pressed,
opens it again (GO's own rule: a press is a press).
```

## Early ride

Inside `_early()`, above `var tries := 0`:

```text
RIDING OUT WITH TIME LEFT TO OPEN LOCAL IN: a solved flight's ride round
to its departure (ruling 20) can be as short as a quarter second, and
one that ended while the map was still being left found the ship flying
(seed 11, Oct 31): what is checked here is LOCAL opened during the ride.
A ride too short for it is flown on to the place, and the flight tried
back the other way, up to RIDE_TRIES times
```
