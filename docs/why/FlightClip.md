The reasoning behind `tkg/scripts/sim/FlightClip.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Flight clip

Above `const END := 34.0`:

```text
The sector map's ship, flown as a player would and filmed with its sound:
  godot --path . --write-movie <out.avi> --fixed-fps 30 -- sheet=FlightClip [seed=N]
Starts a run on the real shell and router, jumps to a system, then on a fixed
timeline: the ship leaves the edge and steers at the first world -- thrusting
until the dotted line says it will slide into orbit, then letting go -- and
the ring takes it; it sits in orbit, W leaves along it; the arrows pan the
view and a drag pans it back; a world is selected with one click and flown to
with a second, on a transfer orbit, ending in orbit; a click on empty space
goes back to the list, and the wheel zooms in. Quits at the end. `nova=S`
forces a distant supernova S seconds in, somewhere clear in the far sky.
`loc` turns LOCATION on first (zoom 2, the ship held in the middle); `log=<json>`
writes every frame's ship -- its mode, whether it is burning onto an orbit,
its heading, where it is drawn on the map, its plane position -- to measure
how smooth it moves.
`tour` flies the auto-flights instead: in orbit of the first world, the next
world selected (its whole flight drawn dotted) and flown to, then the star's
close orbit, then a station, belt, hulk or contact if the system has one --
each leg once the last is on its orbit, the plan shown a second and a half
first. Quits when the tour is done.
  godot --path . -- sheet=FlightClip tape=<wav> [tapesecs=S]
Records the thrust instead, heard as a player hears it: W held from the edge
for S seconds (6), the SFX bus drained from an AudioEffectCapture every frame
(as StationShot's `boardav`) into a 16-bit wav at the mix rate, front pair only.
Silent for the first second; `tapepulse=ON,OFF` presses and lets go of W on
that rhythm instead of holding it, to hear the presses.
`tapesession` plays a player's minute instead, through real key events (so
every listener hears them): W taps from 50 ms to 2 s holds, quick repeats, A,
D and S, LOCATION on and off, a world selected and flown to (its insertion),
leaving its orbit with W, the wheel -- on the master bus with the music and
the room tone muted, and every sound Audio plays logged by name and time
(`<wav>.json`, with the key events).
```
