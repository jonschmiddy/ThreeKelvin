The reasoning behind `tkg/scripts/sim/LadderShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Ladder film

Above `const SVP := preload("res://scripts/ui/sysmap/SystemView.gd")`:

```text
THE ZOOM LADDER'S MOVES, filmed (`ZoomLadder`):
  godot --path . --windowed --position 3840,0 --fixed-fps 30 -- sheet=LadderShot
      keepwindow flow=c out=<dir> [seed=N] [seams=1,2,3] [designs=A,B,C] [style=...]
      [side=<StationSides id>] [interior=<id>|none] [weight=light|medium|heavy] [fit=full]
For each design of each seam asked for, the move both ways through the
Router's own doors -- chart <-> map, map <-> LOCAL (in orbit of a world, so the
world handoff has its world), LOCAL <-> station (DOCK on LOCAL's bar, UNDOCK)
-- every frame of the game's 960x540 picture saved as
<dir>/<seam><design>_<in|out>/f_####.png, from a few frames before the call to
a few after the move. The ladder's clock steps 1/30 s a frame, and with
`--fixed-fps 30` so does the game's, so the frames play at true speed at
30 fps however slowly the window drew. Prints, per clip, the frame the screens
changed hands on (`swap`). Needs a window.

`designs=picks` films each seam's default (Jon's picks: 1A, 2C, 3B) instead of
every letter. `post=N` keeps filming N frames after the move ends (default 8),
so the UI that arrives after it is on the film. `go` films GO on an event from
the map (`2C_go`, the ship already in orbit where it stands). `dive` films the
moves two distances long that Tab makes: the chart to LOCAL (`dive_chart_local`),
and docked, the berth to the map (`dive_station_map`) and the chart back to the
berth (`dive_chart_station`). `timing` writes no pictures: it logs every real
frame's length (run it WITHOUT --fixed-fps).

`first` (with `timing`): THE FIRST VISITS, as a player meets them on a launch:
the title held `title=S` seconds (6), NEW RUN, the hull pick held `pick=S`
(4), LAUNCH onto LOCAL, Tab to the map, on to the chart, then the same hops
again. Each step prints its longest real frame, how many went over 50 and
100 ms, and what the ladder's probes said on the longest -- the one-off
stalls (a shader compiled on first use, the chart's galaxy built) that a
fixed-fps film hides. `buildcost` adds the chart's star field built cold.
`stills` (with --fixed-fps 60) saves each step's last frame, the sky's clock
held, for a before-and-after diff.
```

## Frame capture

Above `func _shown() -> void:`:

```text
The next frame a player sees. `frame_post_draw` also fires for the draws a
screen forces while it finishes itself (LOCAL's sky primes in up to 48 of them,
never presented), so one picture per process frame.
(read at the top of the next frame: what the last frame finally drew, after
any draws it forced while building itself -- those are never shown, and the
first draw of a frame is often one of them)
```
