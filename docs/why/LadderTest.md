The reasoning behind `tkg/scripts/sim/LadderTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test coverage

Above `var _fails := 0`:

```text
THE ZOOM LADDER'S DOORS, headless (`ZoomLadder`):
  godot --headless --path . -- sheet=LadderTest
Every move between the four distances, through the Router's own doors with the
animation on (`Router.animate_in_harness`) and the ladder's clock stepped
1/30 s a frame: each one lands on the screen it was going to; nothing is left
half-built behind it (no ladder in the tree, the map's camera handed back,
LOCAL's scene and sky at their own size, the bar back, the hull shown); a key
pressed mid-move ends it at once and the screen takes input after; the wheel
past either end of the map, the chart's closest zoom and LOCAL stays put (Tab
and the tabs are the way between distances, never the wheel); LOCAL's DOCK at a station docks, UNDOCK lands on LOCAL; the
defaults are Jon's picks (1A, 2C, 3B), and 3B's dock flies the yard's hull in
from the left with the elevator out of the picture until it has settled, its
undock the elevator out first and the hull away to the left, then on LOCAL
its own way out of the bay with the camera still; a fight
opened from the map arrives on LOCAL and its end goes back; every design of
every seam; and the switch off is today's flow, a plain swap.
```

## Docking choreography

Above `func _hull_flies_in(dock_b: Button) -> void:`:

```text
3B, DOCKING (the Drum): on LOCAL your ship sets off from where it sits and
only ever moves right, the station's lights come on as it goes, and it is all
in behind the lips before the camera pans; the pan carries the yard in from
the right; in the yard the hull comes in from the left and only moves right,
the elevator out of the picture the whole way, the hull ends on its stands,
and only then does the elevator slide back in.
```

## Camera still

Inside `_hull_flies_in()`, above `var dust_prev := {}`:

```text
THE CAMERA STILL (Jon, Oct 20: "Why is there so much parallax? The dust
shouldn't move as the ship comes in. The station is stationary."): from
the dock's first frame to the dip to black, everything LOCAL draws but your
ship -- the station's plate and front and their layers, the wreck row, the
dust, the effects, the subject, the sky -- where it was, each frame
THE DUST AT ITS IDLE (Jon, Oct 20: "The dust move too much"): every mote,
through its place as drawn (`LocalDust._rest_at`), each frame of the dock
up to the dip, moving by its own drift and bob and nothing more
```

## Landing sound

Above `func _yard_heard(label: String, yr: Dictionary) -> void:`:

```text
The landing as `_yard_sample` saw it, and the tape under it: THE ROAR (the
cruise flame drawn and the thrust loop at the dock's burn level while your
ship flies in, nothing before `YARD_ROAR_FROM_S`); THE PUTTER (the clip for
the row picked, at this hull's weight, once, from the flame's first cough,
at the burn's level, the flame drawn on that row's coughs frame for frame);
NOTHING before touchdown (the loop out from the first cough, the last cough
`YARD_QUIET_S` or more before it, the flame at the idle); THE CLAMPS as it
touches down, once.
```

## Elevator slide

Above `func _rail_comes_in(st: StationScreen, rs: Dictionary) -> void:`:

```text
THE ELEVATOR, AFTER YOUR SHIP IS IN, LIKE THE GAME'S OTHER PANELS (Jon, Oct
20: "The left panel coming into the station doesn't come in correctly"):
it starts only once the yard's flight is done (the yard's `_lad` empty on its first
frame), slides as a `PanelSlide` on the panels' curve, in whole pixels, only
ever right, carrying its ground (`_RailBack`) with it so the yard's hall is
never seen through it nor gone from under it at once; nothing on it takes a
click while it moves; and it lands in its place, the hall gone.
```

## Undocking

Above `func _hull_flies_out() -> void:`:

```text
3B, UNDOCKING HOLDS THE BACKGROUND AS DOCKING DOES (Jon, Oct 21: "the
background stays put as your ship flies out, matching docking"). In the yard
as before: the elevator out first, the hull off its stands to the left, the
empty yard down to black. Then on LOCAL, every frame from its first to a
second after the move lands: THE CAMERA STILL -- everything LOCAL draws but
your ship where it was, 0 px (`_bg_state`, the dock's check), the ladder's
camera never zoomed nor panned, every dust mote as drawn moving by its own
drift and bob alone; your ship down the ENTER's path eased from rest to
rest, out through the lips and never back in; its engines at the idle, then
the arrival's coughs, their clip heard once from the first, down to the idle;
the station lit the whole way and after; your ship parked at its mooring at
its own size.
```

## Station layout parity

Above `func _station_same(route: String, at_once: Dictionary) -> void:`:

```text
DOCKED BY A MOVE OR OPENED AT ONCE, THE SAME STATION (Oct 21: built ahead at
DOCK under the ladder, in the engine's theme, it kept that theme's sizes --
your ship's figures in the yard 153 px tall for 144 and hung 9 px high):
every part of `route`'s layout exactly where the station opened at once has
it, at the same size and minimum size.
```

## Skip mid-undock

Above `func _undock_skipped() -> void:`:

```text
A PRESS MID-UNDOCK (`ZoomLadder.finish_now`): docked, UNDOCK, and a key once
your ship is out of the hull and backing out -- the move ends within a frame or
two, your ship parked at its mooring at its own size, its engines at the
idle (the burn out, no flameout begun or heard), the station lit. And under
reduced motion UNDOCK never animates: LOCAL at once, your ship at its
mooring, the station lit.
```

## Station front

Above `func _front_is_plate_less_recess() -> void:`:

```text
THE STATION'S FRONT IS ITS PLATE LESS THE RECESS: on every side the crevice
layer under the front is solid wherever any layer is
drawn, nothing of the front (layers, lamps) is in the recess, and the
lips' rows (`HULL_ROWS`) are solid hull from the recess's end to the plate's cut and
across the window tiled past it -- so your ship, flying on into the hull, is
never seen through it.
```

## One smooth motion

Above `func _one_motion(what: String, track: Array) -> void:`:

```text
ONE SMOOTH MOTION (Jon: "can we make the movement one smooth motion"): what
carries the move, frame by frame -- your ship along the hallway (LOCAL, its
plate px times the zoom), the pan (P), your ship in the yard -- in screen px
a frame. Each piece, from its first movement to its last, never drops below a
floor (no stop mid-piece) and never jumps against its neighbours (no spike);
a piece starting where the last ended on screen (the hallway into the pan)
starts at the speed it ended on. (F's black between the hallway and the yard
is no piece: your ship is out of sight through it.)
```

## First LOCAL parity

Above `func _flyin_is_first_locals() -> void:`:

```text
LOCAL'S OWN ARRIVAL IS THE FIRST LOCAL'S (Jon, Oct 21, "station:BC"): on
LOCAL at the station, the fly-in (`SectorScreen._begin_flyin`) stepped to
every 1/30 s from its start, laid over the first LOCAL's arrival after its
name card: your ship in the same place, at the same size, shown alike, with
the same flame on every flameout row, on every frame it is arriving -- and
no name card.
```

## Station wake sound

Above `func _wake_heard(press: bool) -> void:`:

```text
THE STATION WAKES ON LOCAL, HEARD (Jon, Oct 21: "Can we also get some sounds
for when the station turns on?"): asleep, then woken as LOCAL wakes it
(`SectorScreen._wake`), each frame's lights as set and the tape under them --
a clunk and a buzz on the frame each bank's first lamp lights, the chime on
the frame the warning lights go green, and lit and green-then-gone at the
end, lit for this visit. `press`: a key mid-wake lights it all at once, hushes
what was in the air, and nothing more is heard.
```

## No stand-in picture

Above `func _no_stand_ins() -> void:`:

```text
NO STAND-IN PLACE PICTURE ON LOCAL (Jon, Oct 21: "I don't want the beacon to
show up at all. I want to see the actual event of that planet/POI"): at every
place of every system of the run -- each world, the star, the edge -- LOCAL's
place picture (`AreaView`, `site` as LOCAL sets it) is none; a
station's is the station itself, and only where it is. The sheets (`ANY`)
still draw each picture.
```

## Mirrored

Nov 13: an undock moors the ship on the station's right
(`docs/why/SectorScreen.md#mirrored`). `_hull_flies_out` checks the nose-first
undock: its path (`1 - smoothstep((t / ENTER)^1.5)`), the engines (idle, burn,
coughs, idle), LOCAL drawn mirrored with the nose clear of the edge, and the ship
going left to right on screen. `_redock_from_right` checks a dock from there: LOCAL
to black with the ship unmoved, then the deck's landing, and UNDOCK moors it right
again. Then LOCAL is put back on the station's left, as a flight in leaves it, for
the arrival and dock checks that follow, and before each station side and the
map's DOCK. Each of those docks from the left, which is the flight they test.
`_hull_flies_in` checks that a dock from the left flies.

