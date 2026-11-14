The reasoning behind `tkg/scripts/ui/ThrusterFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Coded engine flame

Above `enum Look { OVERLOAD, DRIVE, SPILL }`:

```text
A STEADY ENGINE FLAME DRAWN IN CODE, from the overload death's plume (Oct 13).

Jon saw the plume in the F OVERLOAD enemy death and wanted it as the normal
engine flame, side by side with the PixelLab strips. This is the MOCKUP for
that pick: nothing live draws it yet. `-- sheet=ThrusterSheet` films it.

SHARED, NOT COPIED. The hull picture (`BreakupCuts.hull_pic`) and the engine finder
(`BreakupCuts.engines`) are the death's own; the plume
builder is still a copy of ShipBreakup's. The
differences from the death's copy, each on purpose:
  - one picture per NOZZLE per length, not one for all engine points, so each
    engine can flicker on its own;
  - the 2x2 Bayer is read in CANVAS coordinates, not the plume's own. A plume
    streaming left grows its box to the left, so a plume-local pattern would
    flip parity every time the length changed by one pixel: the whole dithered
    tail would crawl on every flicker step. Fixed to the ship, it holds;
  - the plume is cut out wherever the hull is opaque, so the flame can be
    drawn as ONE additive layer over the finished ship and still never paints
    over plating. Today's strips need a `back` flag and a draw order for that
    (HullData.thrusters, "kept off the hull plate"); this needs neither;
  - on a rigged hull each stream starts at the strip's own attach pixels and
    the hull blocks it except where the strip itself burns through (see
    `for_hull`);
  - `for_sprite` keeps only points on the hull's back EDGE for a steady flame:
    the death's lit-pixel test also catches warm windows and stripes, and a
    flame streaming out of a window is fine in an explosion and absurd at rest.

THE LIFE. The bands are held; only the LENGTH moves, by one or two pixels, in
held steps a few times a second on one clock per ship (a quarter to two fifths
of a second each, irregular so it is not a metronome). Never every frame: at
five or more changes a second the steps fuse into jitter (memory: judge
animation per second). Not every engine changes on every step, so a ship
with three never pulses as one.
```

## Dynamic flame

Above `var dynamic := false`:

```text
THE DYNAMIC FLAME (Jon picked A at the lively speed, Oct 13, then: "I want
it to be more visually dynamic" and "more sparks and fire coming off the
back"). `dynamic` swaps in the bigger frame loop (`_frame`, `_stream`):
2-4 licks a frame and longer, sometimes a forked tip, band edges moving 1-2
px, the length breathing 2-3 px with the odd surge, the outline wobbling a
pixel side to side along its length, over `loop_n` (12) frames so the loop
does not read as repeating. `particles` adds sparks and torn-off fire
(`particles_at`). Both off is the lively flame as filmed before.
```

## Hull nozzles

Above `static func for_hull(h: HullData, img: Image, the_look: int, seed: int) -> ThrusterFx:`:

```text
A player hull: the nozzles are its RIGGED thrusters (HullData.thrusters).
`img` is the hull picture drawn at canvas (0, 0).

THE FLAME LEAVES WHERE THE PIXELLAB FLAME LEAVES (Jon, Oct 13: "the coded
thrusters should emanate from the same place the pixellab thrusters
emanate from"). Each nozzle is the strip's own attach end: the column its
frames end on (the most common last column, frame by frame) and the rows lit
there in at least half the frames, at exactly those canvas pixels; for a
`back` strip, the column and rows where it first shows past the plating
(behind the hull it is hidden, so that is where it is seen to leave). If that
is a point, the flame starts as a point and gets its body by widening: a
nozzle under ten rows widens up to 3x faster (`widen`), so heavy S's 4-row
apex is not a needle at full burn.
A first try walked heavy S's start out to its cavity's mouth at the dome's
base, and every look then engulfed the dome and read as pasted on.

Nor does it draw over any hull pixel the strip leaves visible: the hull
blocks the flame everywhere except where a FRONT strip covers it in every
frame (the channel the PixelLab flame itself burns through). A `back` strip
covers nothing, so its flame shows only where the hull ends, as today.
`ThrusterSheet` checks both against the strips (`starts`).
```

## Engine size

Inside `for_hull()`, above `var spans: Array = []`:

```text
THE ENGINE'S SIZE (Jon, Oct 13, on the gallery: "the exhaust of these
looks too small on the main body"). The rows the strip starts on are its
narrowest; the flame he is used to is as tall as the engine. So measure
the strip: how tall its visible flame is 2-6 px out from the start, the
middle frame's worth (and its tallest anywhere, for the record). The
coded flame starts that tall, centred on the same axis, at the same
column; a row the start column has under plating walks out to open
space (at most 6 px), as an override's rows do.
```

## Flame axis

Inside `for_hull()`, above `var centre := float(rows[0] + rows[-1]) * 0.5`:

```text
THE AXIS is where the strip's flame centres -- every visible pixel, every
frame -- not the middle of its start rows. A back strip shows first at
the TOP of a slanted or rounded stern, so its start rows sat 4-5 px
above the flame (light A 47 against 51.8, medium B 65.5 against 70.6,
heavy C 95 against 99.6); heavy A's front strips start 2 px high. Jon:
"flame slightly too high".
```

## Mouths

Inside `for_hull()`, above `var start_col: int = at.x + xr`:

```text
THE MOUTHS, read off the hull's own pixels (Oct 13). The stern edge is
found row by row from well behind the strip's start (the first try began
3 px in front of it, and every nozzle sticking further out than that read
as one flat face: light A's three stacked nozzles became one big flame).
A MOUTH is a local minimum of that edge -- rows standing furthest out,
with the edge receding above and below -- grown to the rows within 1 px
of it. Every mouth in the strip's own flame band that this strip is the
nearest to, and that stands within 6 px of the furthest one, is an
engine: three stacked nozzles are three flames, which merge after they
leave. One mouth at least as tall as the strip's flame (read across small
bumps) is a FLAT STERN, and the strip's height sets the start (heavy C,
heavy B). A shallow bell (a front strip lapping its nozzle by a few px)
is a nozzle like any other; only a deep one (heavy S's cavity) keeps the
bell's own shape.
```

Inside `for_hull()`, above `while b6 - a6 >= 2 and _rim_row(img, int(edge[a6]), a6, 1) and not _rim_row(img, int(edge[a6 + 1]), a6 + 1, 1):`:

```text
INSIDE THE OUTLINE: a row at either end whose 4 px from the edge
into the hull are all dark is the nozzle's rim drawn as a line,
not its opening (light B's top pipe: 9 rows with its two rim
rows, 7 inside them)
(a rim is a dark line against a lighter inside: on a hull dark all
through, no row is a rim)
```

## Sternmost engines

Above `func _keep_sternmost(used: Rect2i) -> void:`:

```text
A STEADY FLAME COMES OUT OF THE STERN. The gallery of every ship (Oct 13)
showed the death's detection lighting towers, hull bumps and spires half way
along the body (the Honeycomb's pods, the Spires' masts, the Barnacle's
turret): fine for a breakup, wrong for an engine. Keep only engines within
8% of the hull's length (at least 6 px) of its rearmost pixel, and drop a
one-row sliver when there is anything else.
```

## Bell

Above `static func _bell(cells: PackedVector2Array, apex_x: int) -> Dictionary:`:

```text
A BELL: the hull pixels a front strip always covers, when they run at least
four columns back from the apex (heavy S's stern cavity; a strip that only
laps the hull's edge by a pixel has none). Today's PixelLab flame FILLS it,
wall to wall, and leaves past the rim at the full mouth width. Returns
{cells, depth (columns from the apex to the furthest-out cell), mouth (one
start per row: the first open pixel past that row's last cell)}, or {}.
```

## Picture flame

Above `static func for_picture(tex: Texture2D, k: float = 1.0, half: Texture2D = null) -> ThrusterFx:`:

```text
A SHIP PICTURE'S FLAME (enemies, LOCAL's pool ships): one per picture file,
shared, built off the main thread like a hull's. Its engines are the
finder's, or the hand-placed ones in art/engines.json; `k` is how big the
picture is against the file the table was read off (a pool ship's _half
picture is 0.5). Enemies face left, so it burns to the right.

`half`: the picture's half sheet, when that is what is drawn (an enemy in a
pack of three or more, `EnemyArt.draw_scale`). The rig is still read off the
full picture and then brought down to the half one (`_halve`), as a hull's
half view is; read off the full picture and drawn over the half, every
nozzle sat twice as far from the picture's corner as its own engine.
```

## Living flame

Above `func _frame(n: int, fr: int) -> Dictionary:`:

```text
THE LIVING FLAME (Jon, Oct 13: "They still read as too still... they should
be an active flame"; today's strips change ten times a second and that is
the bar). Each engine cycles LOOP distinct shapes at `fps`, as held frames:
  - the tail is ragged and different every frame: each row's tongue is its
    own length, and one or two rows lick further out (`rag` scales both);
  - the band edges shift a pixel along the flame (`shift`);
  - the length breathes by up to 3 px, so the core with it (`dL`);
  - now and then an ember breaks off the tail and fades over three frames.
What never moves: the nozzle's start (d = 0 is always lit, whatever the
frame), and inside heavy S's bell only the bands shift, gently.
Pure in (engine, frame): the same frame is the same picture every loop.
```

## Sparks and fire

Above `func particles_at(n: int, thrust: int, t: float) -> Array:`:

```text
SPARKS AND FIRE OFF THE BACK (Jon: "more sparks and fire coming off the
back"). Particles, not frames, so they never repeat with the loop, and
STATELESS: particle i of engine n is born at a time, place and speed drawn
from (ship seed, engine, kind, i), so any `t` can be drawn on its own and a
film is the same every run.
  sparks  bright single pixels shed along the TAIL (55-100% of its length,
          never at the nozzle), flying back 1-2 px a frame (at 30 a second)
          with a little drift, cooling white, yellow, orange, red over 4-8
          frames;
  fire    ragged 2-4 px clumps torn off the tail tip, drifting back slower,
          cooling and shrinking over 6-10 frames.
The heat ramp and the look's own levels and dither (the canvas's Bayer, so
the pattern is the ship's). A pixel on the hull is never drawn: they fly
into the open space behind the ship. On heavy S they leave past the rim.
Returns [{x, y, band, k}] in canvas pixels.
```

## Bell light

Above `func _bell_light(bell: Dictionary, L: int, Lf: int, spread: float, streams: Array,`:

```text
THE BELL'S LIGHT (heavy S). The cavity is always FILLED, every cell the
strip always covers, brighter toward the rim as today's flame is, and past
the rim the flame leaves at the mouth's full width with the look's own
spread and falloff. Jon, on idle: "The flame should extend slightly out of
the ship ... that little depression is the entire exhaust" -- so idle is the
same shape, dimmer: the bell held in the second band (0.52 to 0.70, no white
core) and the full idle length past the rim, at 0.75 of the light.
Cruise and full: the bell 0.55 to 0.95 and 0.7 of the length past it.
Living: the bell only shifts its bands (0 to +0.08); the part past the rim
gets the whole loop. Nothing here touches a hull pixel the strip leaves
visible: cells are the strip's own, and the streams are cut out by the hull.
```
