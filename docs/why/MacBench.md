The reasoning behind `tkg/scripts/sim/MacBench.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Mac bench

Above `const ALL_SCREENS := ["title", "chart", "map", "map2", "local", "fight", "yard"]`:

```text
WHAT A FRAME COSTS ON THIS MACHINE, at the window sizes and settings a player
can choose, on the screens a player sits on:

  tools/dev/render.sh -t 1200 --path tkg -- sheet=MacBench
      [scales=1,2,3] [looks=flat,crt] [gfx=high,low]
      [screens=title,chart,map,map2,local,fight,yard]
      [frames=120] [seed=N] [out=<json>]

MANUAL AND WINDOWED, NOT IN THE GATE. It reads the GPU, which a headless run
does not have (the dummy renderer reports 0 and never emits
`frame_post_draw`), and it sizes its own window up to 3x, which on a laptop
covers the screen: don't touch the window while it runs, a click or a key
changes screens under it (input is swallowed, but not by the OS). About ten
minutes at the defaults; one scale with `frames=60` is about three.

WHY IT EXISTS (Oct 27). "The game chugs on my Mac" (Intel Iris Plus 645, a
Retina screen) and nobody had ever measured a frame on that machine, or on
any integrated GPU: every budget in the code was set on an RTX 3070. The
headless profilers cannot see the GPU, the window, vsync or the shell's
passes at the window's own size, which is where a Retina Mac differs: its
WINDOWED default was 3x, 2880x1620 window pixels for a 960x540 game, until
the 2X cap of Oct 27 (`DisplaySettings.RETINA_MAX_SCALE`; there 3 is held to
2 and skipped). So this measures exactly those, on the real screens, in one run:

  * THE WINDOW AT 1X, 2X AND 3X, set through `DisplaySettings.set_scale` as
    the WINDOW SIZE row sets it (a scale the screen cannot hold is clamped,
    and the run says what it got).
  * VSYNC OFF AND NO FRAME CAP, so a frame time is the frame's cost and not
    the monitor's 16.7 (`chartbench` learned this: with vsync on, still and
    dragging both read exactly 60 fps).
  * TITLE, STAR CHART, SECTOR MAP at its home zoom and at zoom 2, LOCAL in
    orbit of a giant, a FIGHT there, and the station's YARD (a city's, the
    one with the lift cars).
  * AT LOOK FLAT AND CRT (the default, the gentle tube) x GRAPHICS HIGH and LOW.

AND FOR EACH, over `frames` frames after the screen has settled (and at
least `MIN_SECS`, see TIME_PROCESS below):
  frame time p50, p95 and the worst (ms, the real clock between presented
  frames);
  PROC and DRAW, each frame cut in two on the engine's own signals (means,
  ms): PROC from `process_frame` to `frame_pre_draw` (every `_process`, the
  `_draw` calls queued by `queue_redraw`, the deferred calls: the game's
  scripts), DRAW from `frame_pre_draw` to `frame_post_draw` (the engine
  handing every pass to the driver, the swap, and any wait on a GPU that has
  fallen behind: with vsync off a GPU-bound frame waits here). What a frame
  lasts beyond the two is physics, input, audio and this sheet's own reading;
  `TIME_PROCESS` as the engine reports it: the slowest frame's process AND
  draw in the last whole second (`main.cpp`: the max of a second, set once a
  second; not a mean, and not the scripts alone). Read once at the end of a
  sample of at least `MIN_SECS`, so the second it covers lies inside it;
  the GPU time of the WINDOW (`get_tree().root`: the shell's black back, its
  hidden frame and the glass shader, all at the window's size), of the GAME
  VIEW (`GameShell.view`, the 960x540 frame) and of EVERY OTHER VIEWPORT
  drawn that frame (the chart's sky, LOCAL's sky and near world, the map's
  scene: each a pass of its own that the game view only samples), and draw
  calls;
  and RENDER CPU: what the engine's own stamps put on handing those same
  passes to the driver (`viewport_get_measured_render_time_cpu`, every pass
  summed), the part of DRAW that is not the swap or a wait.

A VIEWPORT NOT DRAWN THIS FRAME KEEPS ITS LAST READING (the engine only
stamps a viewport when it draws it), so a sub-viewport's reading is counted
only on a frame where it changed: one drawn once at build (`UPDATE_ONCE`)
would otherwise be added to every frame.

THE GPU COLUMNS READ 0 ON JON'S MAC (Oct 27: LocalShot's "game view gpu" and
this sheet's, on Apple's OpenGL 4.1 with the Iris Plus 645). The engine asks
GL for timestamps (`glQueryCounter`) and gets nothing back there, so the run
says so at the end. Then the frame time IS the measure, and DRAW is where
the GPU shows: with vsync off a frame lasts as long as its slowest side, and
a DRAW well over RENDER CPU is the driver waiting on the GPU.

(`TIME_PROCESS` was read every frame and averaged until the first review,
Oct 27: that averaged a once-a-second worst which still held the previous
screen's switch, and printed 242 ms beside 16 ms frames.)

It prints the machine first and last: the OS and CPU, the adapter and its
API version, the driver, the screen's size and scale, the window, vsync,
and the power state (`pmset`: on AC or battery, the thermal limits). Plug
in and close what is heavy before trusting a number; a worn battery near
empty throttles the CPU to half.
```

## Input guard

Above `func _input(event: InputEvent) -> void:`:

```text
NOTHING FROM THE KEYBOARD OR THE MOUSE while it measures: the window takes
focus as it opens, and a Tab or a click on a HUD tab swaps the screen being
measured for another (`chartbench`'s "previously freed" crash).
```
