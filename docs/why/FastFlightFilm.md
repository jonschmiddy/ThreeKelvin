The reasoning behind `FastFlightFilm`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Film usage

Above `const ShipFlightS := preload("res://scripts/ui/sysmap/ShipFlight.gd")`:

```text
THE FAST TRANSFERS, FILMED (Jon, Nov 4-5: "almost 4 times slower than feels
good", "Why is transferring between planets a straight line?"):
  godot --path . --windowed --resolution 960x540 --fixed-fps 60
      --write-movie <dir>/f.avi -- sheet=FastFlightFilm [seed=N] [sys=<name part>|<index>]
      [from=<body>|edge] [to=<body>] [twin] [autopilot=direct|curved] [flight_pace=K]
      [lookaids=0] [worldpace=K] [title=<words>] [hold=S] [lead=S] [out=<json>]
The real map of one system (by default seed 4242's IOTA TALLOW, Jon's V to
IV), the ship parked in orbit of `from` (or, `from=edge`, just arrived by
jump, its arrival played), `to` selected so its line is drawn as a first
click draws it, and `lead` s later clicked again (`fly_to_body`); held until
the ship is settled in orbit there and `hold` s more. Timed on the map's own
clock (`view.t`, which moves by each frame's delta: real time, never the
wall clock the movie writer races), and printed with the flight's bend and
turn (`FlightSolve.shape_of`) as `FILM {json}`. A caption in the corner says
the path, the pace and, once settled, the seconds. `worlds`: no flight,
`hold` s of the map with the ship parked, for the worlds' pace strip; the
seconds a lap of the first worlds, the giant and the pair printed.
SLOW MOTION (`slow=N`, Jon learned the orbiting pair from one-minute films):
from the moment the ship can fly the map runs N times slower
(`Engine.time_scale`), every wait N times longer, so a film written at 60
frames a second plays it at 1/N speed; the caption says so. THE TRAIL
(`trail=0` drops it): where the ship has been since the click, kept, and
once it has landed the straight line from where it left to where it
arrived, so the arc reads against it. `worlds marks`: each world's place as
the strip starts marked and its path since drawn; `lapse=X`: the map run X
times faster (a time-lapse, the ship and the weather hidden, which would
strobe), `hold` then in map seconds.
```
