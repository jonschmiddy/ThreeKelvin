The reasoning behind `tkg/scripts/sim/MenuTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Motion lockup

Above `var _tree: SceneTree`:

```text
The escape menu after the motion settings change under it:
  godot --headless --path . -- menutest

Jon: "Clicking reduced motion and/or clicking skip animations makes the
escape menu lock up?" It did, on one path. A menu opened UNDER reduced motion
never set its backdrop's `amount`, because only the animated way in set it.
Turn reduced motion off in Settings and the way out is animated again, and
`close` read that `amount`: null, `as float` threw, and `close` stopped
halfway. Main had already let go of the menu, so it stayed up, swallowing
every click, and Escape opened a second one over it.

HEADLESS NEVER ANIMATES (`Router.animating`), which is why no test saw it.
This one turns the animations on with `Router.animate_in_harness`, so the
tweens and the animated close really run.

Each case opens the menu with Escape, goes into Settings by its button,
changes the motion settings, and then checks the menu still answers: Escape
leaves Settings, BACK leaves Settings, Escape shuts the menu and it is GONE
from the tree, and the ship screen takes its keys again. The settings are
changed in memory and the panel redrawn, as the chip does, without the save:
the player's settings file is never written.
```

## Frame cap and vsync

Above `func _pacing_case() -> void:`:

```text
FRAME CAP AND VSYNC (Jon, Oct 27, perf C3: "yes"). FRAME CAP offers NONE,
30, 60 and 120; VSYNC is ON or OFF, and OFF only with a cap: OFF with the
cap at NONE sets it to 60, and NONE turns VSYNC back on. Every value reaches
`Engine.max_fps` and the window's V-Sync (`applied_vsync`, which is what was
handed to `window_set_vsync_mode`, and the window's own reading when there
is a window to ask). A file from before VSYNC loads ON with its cap and
leaves the window's V-Sync alone; one that says OFF with no cap loads ON.
Pressed through the real chips, in a scratch settings file, never the
player's.
```

## Auto graphics

Above `func _auto_graphics_case() -> void:`:

```text
GRAPHICS PICKED FOR THE MACHINE (Jon, Oct 27, ruling C1; `GpuProbe`). The
adapter's name is a hint (Intel but not Arc is weak; Apple never), the
measure decides (a heavy HIGH sky is LOW, a sky measured on LOW is judged by
what HIGH would cost; a GPU that reads 0, as a Mac's does, by the title's
median frame; no reading leaves it to the hint). A settings file from
before `graphics_by` loads: HIGH as nobody's, LOW as the player's. Nobody's +
a heavy measure: LOW, kept once in the file, nothing rebuilt under the
picture (no `render_style_changed`), never decided again, and read back so.
Settings says it beside the GRAPHICS row (a line and its tooltips), clear of
the rows round it in the real drawer at 960x540, and HIGH pressed makes it
the player's. The player's HIGH is never touched, by the hint or a measure.
A forced `graphics=` / `style=` and an ordinary harness never measure or pick.
All in a scratch settings file, the hint's adapter stood in for.
```

## Tutorial toggle

Above `func _tutorial_case() -> void:`:

```text
TUTORIAL ON / OFF (Jon, Oct 20: "Have a setting in the options for tutorial
on or tutorial off"): the row is in Settings' HINTS with ON picked on a fresh
file, OFF is kept and read back (written to a scratch settings file, never
the player's), ON brings it back; and pressing REPLAY TUTORIAL does not move
it (nothing clickable moves).
```

## Frame counter

Above `func _meter_case() -> void:`:

```text
THE FRAME COUNTER (`FpsMeter`, Settings' FRAME COUNTER): the rate and the
mean frame, and the WORST frame of the last second -- the one a rate hides
and a player feels. A frame held for 90 ms has to read as the worst, and be
gone from it a second and a half later; and the meter stays top-level, in
no layout (`872f546` removed one that was a child of the HUD row).
GONE MEANS THAT FRAME IS GONE, not that every frame since was under 85 ms:
the gate runs three at once on an 8 GB Mac, and a stall of the machine's
own in that second is not the meter's fault (Oct 27 review).
```

## First launch window

Above `func _first_window_case() -> void:`:

```text
THE FIRST LAUNCH'S WINDOW (`DisplaySettings.first_launch_window`; Jon's
release-check pick A, Oct 18). With no settings file: BORDERLESS where a
window could only be 1x (a 1080p screen), else a window at the largest size
that fits. A settings file that exists is never overridden. Through the real
`load_and_apply`, on a scratch file.
```

## Retina window

Above `func _retina_case() -> void:`:

```text
A RETINA MAC'S WINDOW STOPS AT 2X (`DisplaySettings.RETINA_MAX_SCALE`; Jon,
Oct 27, ruling C2). On stand-in screens (`DisplaySettings.test_screen`,
`test_retina`), since no machine the gate runs on is a Retina Mac and
headless has no screen: "looks like 1440x900" (2880x1800 pixels) offers 2X
at most and its first launch is a 2X window, where the same screen off a Mac
still offers and opens 3X, and a 1080p screen is unchanged; a settings file
saved before the cap at 3X opens at 2X on a Retina Mac and stays 3X off one,
and a saved BORDERLESS is kept; Settings' WINDOW SIZE row on that Mac has no
3X chip, says why, and fits the drawer at 960x540 with nothing overlapping.
A scratch settings file, never the player's.
```

## Motion rows

Above `const PLAYER_MOTION := ["ANIMATION", "CLICK TO SKIP JUMP", "SCREEN SHAKE", "FRAME CAP", "VSYNC"]`:

```text
MOTION HOLDS THE PLAYER'S ROWS, EVEN IN DEV MODE. The zoom ladder's
developer rows -- ONE CAMERA, each seam's design, 3B into the yard, the move
timings and the station lights -- were built there under `DevMode.enabled`
until Jon had them out, Oct 19; what he had them on is `ZoomLadder`'s
constants. So the section, built with dev mode on, names exactly ANIMATION,
CLICK TO SKIP JUMP, AUTOPILOT (Nov 5), SCREEN SHAKE, FRAME CAP and VSYNC (Oct 27); and a settings file still
holding the old `[flow]` keys loads without a word and moves nothing. AUTOPILOT
(Jon, Nov 5, "AUTOPILOT: DIRECT . CURVED"): a file with no key for it, or a
word it does not know, loads CURVED; DIRECT saved loads DIRECT.
```

## Graphics pick e2e

Above `const PICK_SCRATCH := "user://titlepick_settings.cfg"`:

```text
THE PICK ON THE REAL TITLE, END TO END (the review of Oct 27). Everything in
`_auto_graphics_case` drives `GpuProbe` and `DisplaySettings` by hand; the part
that makes the pick had never run anywhere: the title's sky stepping its probe
every frame (`ChartSky._gfx_step` over `sky_viewports`), `GpuProbe.conclude`,
the picked pass compiled (`warm_place`), the title keeping the pass it has
(`low_held` in `_push`), and the next sky drawing the pick. On an Intel Mac a
dead measure looks like a working one (the hint has LOW up before it), so
these titles run on chips with no hint. Headless never bakes the sky, so the
bake's GPU products are stood in for (`ChartSky.stand_in_bake`; the CPU's
share is real), and the dummy renderer's GPU timer reads 0, as a Mac's does:
  A: a GPU timer (Windows) reading a heavy sky (`GpuProbe.force_ms`): LOW.
  B: no GPU timer (a Mac), the frames slow on the wall clock: LOW.
  C: no GPU timer, the frames as fast as they come: what they say, kept.
RADIANT's safety on the same sky waits for the pick and never judges a held
pass, and does judge a sky drawn as it will be. Each title over a scratch
settings file nobody has set; each wait fails at its timeout, never hangs.
```
