The reasoning behind `tkg/scripts/ui/GpuProbe.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Graphics pick

Above `const SETTLE := 12`:

```text
WHAT THIS MACHINE'S GRAPHICS CAN HOLD, MEASURED: some viewports' GPU time,
averaged over their first frames of drawing. It was RADIANT's safety alone
(`ChartSky._radiant_safety`, Oct 5); it is every style's now, because the
same measure picks GRAPHICS for a player who never chose it (below).

GRAPHICS LOW, PICKED FOR THE MACHINE (Jon, Oct 27, ruling C1: "yes"). Every
budget in this game was set on an RTX 3070, and on an Intel laptop chip (Jon's
Mac: Iris Plus 645, about 1/25 of its shader rate) the HIGH sky alone runs past
a 60 fps frame. LOW is every style's cheaper path, and nothing ever turned it
on: a player had to know to look. So on the title, for a player who never set
GRAPHICS (`DisplaySettings.graphics_by`), the title's sky is measured once
and the answer is kept for good (once per profile, never again). A player who
pressed HIGH or LOW is never touched.

THE ADAPTER'S NAME IS ONLY A HINT. On the launch that is still undecided, an
Intel chip that is not an Arc starts on LOW at once, before the title is
built, so its first picture is already the cheap one (an Apple chip never
does, whatever it measures later). The measure then decides: it can keep LOW
or put HIGH back.

A MAC CANNOT TIME ITS GPU. Apple's OpenGL answers every GPU timer with 0
(Jon's Mac, Oct 27: `-- chartbench` read "GPU 0.00 ms" on every sample, HIGH
and LOW). So the GPU's time is the measure where there is one, and where it
reads 0 the title's frame time on the wall clock is (its median, the window
focused): a title that cannot hold 60 frames a second is a weak machine.
That sees less (vsync rounds a frame up to the screen's next refresh) but is
still a measure; with neither (a frame cap under 50 hides it too), the hint
stands for that launch and nothing is kept: the title measures again.

NEVER UNDER A PICTURE: the pick is saved without `Sig.render_style_changed`,
as RADIANT's own fall-back is (`DisplaySettings.fall_back_style`), so the
title keeps its look and the next picture built (the run's chart, the map,
LOCAL, the next title) draws the new one. And never under a harness, nor a
launch that forced `style=` or `graphics=`: those ask for what they measure.
```

## LOW share

Above `const LOW_SHARE := 0.48`:

```text
What LOW costs against HIGH on the same machine, for a title measured on LOW
(the hint put it there): its time over this is what HIGH would have cost.
Measured on Jon's Mac (Iris Plus 645, Oct 27, seed 4242, the window at 1x,
vsync off: `-- chartbench` and `-- chartbench graphics=low`): the title 6.20
ms a frame on LOW against 12.88 on HIGH (0.48); the chart 0.43 still, 0.31
at zoom 6.
```

## GPU timer

Above `static var _reading := {}`:

```text
THE GPU TIMER GOES OFF AGAIN. `viewport_set_measure_render_time` runs timer
queries every frame it is on, and a probe that turned it on and never off left
them running on the title's viewports for the rest of the screen, every launch
nobody had set GRAPHICS (and RADIANT's safety the same on RADIANT). Two probes
can read one viewport (the title's pick and RADIANT's safety share the sky), so
each viewport counts the unfinished probes reading it and the last one out
turns its timer off.
```

## Verdict

Above `static func verdict(full_ms: float, measured_low: bool, weak_hint: bool, frame_ms: float = 0.0) -> bool:`:

```text
THE VERDICT: LOW or not, from the sky's full-screen GPU time and whether it
was measured on LOW; where the GPU read 0 (a Mac), from the title's median
frame on the wall clock; with neither (headless, a cap that hides it) the
hint's, which `conclude` never keeps. Measured on LOW, a time is judged by
what HIGH would have cost.
SO AN INTEL MAC KEEPS LOW. Its title is measured on the hint's LOW, on the
wall clock, under vsync: a frame is never under the refresh (16.7 ms at
60 Hz), and 16.7 / LOW_SHARE is 34.8, over FRAME_MS. A LOW that holds 60 says
nothing about HIGH, so the measure can only put HIGH back where the GPU can be
timed (Windows) or the screen refreshes at 100 Hz or more. Jon's own Mac on
HIGH (12.88 ms, at 1x and vsync off) would pass FRAME_MS on the wall clock;
on his Mac the chip's name decides, not the measure.
```
