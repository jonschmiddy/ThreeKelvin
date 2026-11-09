The reasoning behind `tkg/scripts/sim/ChartLook.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Chart look

Above `var out := "user://chartlook"`:

```text
The star chart photographed at chosen views, whole and with its systems
hidden, at the chart's own size (1x) and doubled (2x, game scale, for
judging):
  godot --path . -- sheet=ChartLook out=<dir> [kind=N] [views=name:Z:X:Y,...] [clock=T]
    [nebkind=F:T] [allsys] [calm] [style=painted|radiant] [graphics=low] [runseed=N] [corekeep=0]
    [at=N|darkF] (YOU at system N, or beside the first dark cloud, F of its radius out)
    [boltclock] (the clock on the first emission cloud's next held lightning bolt)
A view is a zoom and a pan in VIEW PX at zoom 1 (the showcase's units, 622.25
a galaxy unit, the chart's own projection), the frame's centre: `core:1.5:0:0`.
X may be `ship` (centred on YOU) or `neb` / `nebK` (centred on a cloud that
shines, or one of NebulaField.Kind K; `nebK.N` the Nth of that kind). The
default views are the showcase's heroes: opening 0.42, core 1.5, a nebula at
4 and the hole at 6. `clock=T` holds the sky's clock at T seconds
(`MapChart.clock_override`, default 600, the showcase's stills); `calm` turns
reduced motion on in memory; `nebkind=F:T` makes the first cloud of kind F
kind T for the shot; `style=` and `graphics=low` are read by DisplaySettings.
THE SOLID LOOK in any style (`ChartSky.SOLID_STYLES`): `solidstyle=<style>[,...]`
draws those styles through the camera before their line in the table is on (with
`style=` the same stills, tours and costbench film any style the same way);
`chartflat` draws every style flat, as before the solid look (a "before").

CLIPS, for measuring motion (sky only, chart rect at 1x, `f_NNNN.png`, for the
showcase's `tools/frames.py`):
  zoomclip=<dir> clipview=Z:X:Y [clipzoom=1.1] [clipframes=61]
    a slow zoom: the zoom times `clipzoom` over the frames, the clock frozen
  panclip=<dir> clipview=Z:X:Y [clipframes=61]
    a slow pan, 12 view px over the frames, the clock frozen
  liveclip=<dir> clipview=Z:X:Y cliptime=T0:T1:N [turn=title] [clipwait=1]
    the sky's own motion at one view, the clock stepped from T0 to T1
    (`turn=title` at the title's turning speed; `clipwait=1` a frame drawn a
    step, so a 20 s clip at 60 steps a second is the game's own frames)

Writes <view>_full.png and <view>_sky.png (1x) and <view>_2x.png (sky, 2x).
Prints the bake's time. Needs a window; leave it alone while it runs.
```

## Torn clip

Above `func _torn_clip(dir: String) -> void:`:

```text
TORN AWAY's film (`tornclip=<dir> [tornto=N] [tornfrom=S] [clipframes=300]`): 30
frames a second of the game's clock, two drawn a frame; 1 s on the dwarf at zoom
1.6, 5 s easing out to the opening (the giant and the stream come into view), then
the rings falling away at the opening from `tornfrom` s, evenly to half a second
before the end, each fall eased over 0.4 s and held (to `ChartTorn.max_lost`). The
marks are drawn.
```

## Chart tour

Above `func _tour(dir: String) -> void:`:

```text
THE TOUR: a player's first look, the same every run, for a before and an
after at the same state (`tourclip=<dir> tour=dive|core|pan|open [icons]
[tourat=fx:fy|ship]`). 30 frames a second of the game's clock, one frame
drawn a step, the moves made through the chart's own wheel and drag code (so
the far sky's parallax is the game's):
  dive  1 s at the opening, 5 s of wheel in toward `tourat` (5.7x), 2 s of
        drag, 1 s still
  core  the core at 1.2, 5 s in to 3.6 about the middle, 2 s still
  pan   the arms at zoom 1, 8 s of drag across them, eased
  open  3 s still at the opening, then the dive
  sn        the next supernova at zoom 1.4 on its star, from 1.5 s before, 12 s
            (FORCED into the clip: the clock is set to it)
  remlapse  the opening as the clock runs 20 minutes at 120 times (a time-lapse:
            the supernovae's remnants coming and fading)
  remhold   the inner disc at 1.4, 10 s at the game's speed (the last ten
            minutes' remnants standing in the gas)
  zoomin    the arms at 0.6, 6 s of wheel in about the middle (5x), 1 s still
  soliddrag at `tourzoom` (the opening's 0.42 if not given), a slow drag: 4 s
            sideways, 4 s down, 5 s on a diagonal back up, each with a breath
            after it
  soliddraglong  the same, then four seconds' hold (the second after release)
  openzoom  the opening, 6 s of wheel in about the middle (3x), 1 s still
  skypan    Jon's void framing (1.2 at -220,-200), a slow steady drag: 90 px
            sideways over 6 s, no easing (the far stars' slide, frame by frame)
```

## Cost bench

Above `func _cost_bench(names: String) -> void:`:

```text
WHAT A PART OF THE SKY COSTS (`costbench=remnants,solid,fluff,edge,terrain,nebulae|none`): one process,
one galaxy, the part switched off and on in turns at each view (the opening, the
arms at 1.2, the arms at 2.5, the hole at 6), eighty turns of eight frames,
vsync off; every frame's own GPU time of the sky's viewports, and the whole
frame's, compared at the 20th percentile (the frame with the least of the rest
of the machine's load on it) and the median. Interleaved because this machine is
shared: two separate runs of `chartbench` differed by half a millisecond with
nothing changed. `none` switches nothing, to show the noise. Remnants are
switched by `ChartSky.diag` 2048; the solid galaxy by `ChartSky.solid`; the gas's
puffs by `ChartSky.fluff` (as the command line asks for them, against none); the
dissolving edge by `ChartSky._edge_on`; the middle's relief by `ChartSky._terr_on`; the
nebulae's bodies by `ChartSky._neb_on`.
```

## Solid test

Above `func _solid_test() -> void:`:

```text
THE SOLID GALAXY'S MARKS ARE WHERE ITS SKY IS (`solidtest`, with
SIMPLIFIED): after a slow drag (a slide) and a zoom, the place pass is
made to write, in each block, the point of the disc's plane it shows
(`ChartSky.diag` 4096) and read back; at every system the chart draws, that point
is put through the chart's own projection, and must land within 1.5 px of the
system's mark: within 2.25 px, which is the flat chart's own agreement -- a block
is 2 px (its middle at most 1.41 px from anything in it), the marks are redrawn
for the galaxy's turn only when it has moved half a pixel, and the read-back is
half floats (measured with the camera off: 2.09 px at worst over 638 marks). And
a click on each mark with no other within twice the chart's pick radius must
pick that system (`_node_at` takes the first within it). Prints the
worst and FAILs past it. The sky shader against the chart's GDScript: two codes,
one projection.
```
