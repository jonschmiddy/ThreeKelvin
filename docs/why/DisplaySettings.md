The reasoning behind `tkg/scripts/ui/DisplaySettings.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Display modes

Above `enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }`:

```text
Display mode and monitor, persisted to user://settings.cfg.

Every mode positions itself against a chosen screen rather than the desktop
origin. Borderless used to sit at (0,0), which is the top-left of the whole
virtual desktop, so on a multi-monitor setup it always landed on whichever
monitor happens to be leftmost.

The viewport is 960x540 and scales by whole numbers only, so a windowed size
is always an exact multiple. max_window_scale() is what stops the window from
growing to the height of the screen and pushing its own title bar out of
reach — a trap this project hit once already.
```

## Settings path

Above `static var HARNESS_PATH: String = TestRun.scratch("settings", "cfg") if TestRun.active() else "user://harness_settings.cfg"`:

```text
Where these settings are read and written: under any harness
(`TestRun.active()`), a scratch file, so a test never touches the player's
own. It used to be the player's file for every harness but the few that
pointed it elsewhere, and the boot writes it: `load_and_apply` ends in
`apply`, which ends in `save` -- so every `sheet=` shot run without
`keepwindow` rewrote the player's settings.cfg, and RADIANT's safety
(`set_render_style`) could save SIMPLIFIED over the player's style. Audio and
Keys keep their sections in the same file, so they follow this path too.
(one per harness PROCESS, `TestRun.scratch`, as the save and the history are:
a shared one carried one harness's settings into the next, and two running
at once wrote over each other)
```

## Frame counter

Above `static var fps_meter: bool = false`:

```text
Show the frame counter. Off by default.

A SETTING RATHER THAN A DEV FLAG. It rode on `DevMode` for one commit, which
meant a player could not see their frame rate without also unlocking the card
gallery and the whole star chart -- and the counter is a diagnostic, not a
cheat. The number a tester quotes when a screen feels choppy should not cost
them the game's secrets.
```

## Skip jump

Above `static var skip_jump: bool = false`:

```text
WHETHER A CLICK CUTS THE JUMP SHORT.

OFF, and that is the interesting default. The jump is seven seconds of
departure, transit and arrival that the run has been building to, and a
player who is holding the mouse while it plays -- which is everybody, they
just clicked JUMP -- skips it by accident and never sees it again. So the
skip is there for the player who has seen it enough, and they have to say so.
```

## Frame cap

Above `const FRAME_CAPS: Array[int] = [0, 30, 60, 120]`:

```text
FRAME CAP's chips, in Settings' order. 30 joined NONE, 60 and 120 on Jon's
call (Oct 27, perf C3): on a slow machine whose frames take 20 to 33 ms,
V-Sync shows them at a jumpy mix of 60 and 30, and a 30 cap paces them
evenly and saves power. Opt-in; NONE stays the default.
```

## V-Sync

Above `static var vsync: bool = true`:

```text
V-SYNC, ON by default (Godot's own, and project.godot never changes it).
OFF ONLY WITH A CAP (Jon, Oct 27, C3): with V-Sync off and no cap the game
draws as fast as it can, which on a turn-based screen is just heat. So OFF
with FRAME CAP at NONE sets the cap to `VSYNC_OFF_CAP`, and FRAME CAP set to
NONE turns V-Sync back on (`set_vsync`, `set_frame_cap`; a file that says
otherwise loads with V-Sync on). The window modes are left as they were:
FULLSCREEN is still exclusive, on Windows too.
```

## Render styles

Above `const STYLES: Array[StringName] = [&"simplified", &"painted", &"radiant"]`:

```text
HOW THE STAR CHART AND THE SECTOR MAP ARE RENDERED. Three styles, in the
order Settings lists them (Jon, 2026-10-05, after the "Rendered Again"
showcase and the port): SIMPLIFIED, the game's layered look refined and set
in motion (direction C, "Alive", THE DEFAULT for now); PAINTED, every pixel
placed by a pixel artist's hand (direction B, "for aesthetics"); RADIANT,
light through gas (direction A, "for photos probably"). All of them share
SIMPLIFIED's animations and its black hole (`LegacyHole`, named before the
rename). LEGACY, the look from before the port, was a fourth until Jon let it
go (Nov 7: "legacy feels too realistic"); a file or a harness that still asks
for it gets SIMPLIFIED (`valid_style`).
```

## Graphics ownership

Above `const GFX_NOBODY := ""`:

```text
WHO SET GRAPHICS (Jon, Oct 27, ruling C1: LOW picked for a weak machine).
settings.cfg could not tell a player who chose HIGH from one who never
looked: both saved `graphics_low = false`. Now it says. NOBODY: never set, so
the title's sky may measure this machine and pick (`GpuProbe`), once. MACHINE:
it did, and that is final; Settings says so beside the row until the player
picks. PLAYER: HIGH or LOW pressed in Settings, never touched again.
A FILE FROM BEFORE THIS KEY: LOW was the player's (HIGH was the default, so
LOW was pressed); HIGH cannot be told from never chosen and counts as NOBODY,
which is every alpha player on the default (`graphics_by_in`).
```

Above `static func set_graphics_low(on: bool) -> void:`:

```text
GRAPHICS LOW from Settings: kept, and applied at once -- the star chart, the
sector map and LOCAL rebuild on `Sig.render_style_changed` and read this as
they build (the chart also swaps its place pass live). Turning LOW ON lets
RADIANT try again if its safety had dropped it to SIMPLIFIED: what was too
heavy on HIGH may hold on LOW, and the safety measures the LOW path.
The player's own, from now on (`graphics_by`): the machine never picks
again. Pressing the chip already marked still counts as choosing it.
```

Above `static func machine_pick(low: bool) -> void:`:

```text
THE MACHINE'S PICK (`GpuProbe.conclude`), once per profile and only while
nobody has set GRAPHICS: kept, but NOTHING IS REBUILT NOW, as RADIANT's
fall-back (`fall_back_style`) -- the picture up keeps its pass and the next
one built draws `low`. LOW picked lets RADIANT's safety try again, as the
player's LOW does (`set_graphics_low`). Settings, if it is open, redraws its
row (`Sig.graphics_picked`): a drawer left with HIGH marked over a LOW pick
could not be pressed back to HIGH until it was opened again.
```

## Radiant safety

Inside `set_render_style()`, above `if s == &"radiant":`:

```text
CHOSEN AGAIN, IT IS TRIED AGAIN: RADIANT's safety (`ChartRadiant.fell_back`)
held it off for the rest of the session, which was meant to last only
"until the player chooses it again" -- and nothing ever let it go, so a
player who picked RADIANT back (say, on LOW) got SIMPLIFIED under a
setting that said RADIANT. The safety measures it afresh.
```

Above `static func fall_back_style(s: StringName) -> void:`:

```text
RADIANT'S SAFETY GIVES UP ON IT (`ChartRadiant.fell_back`): the setting
becomes `s` and is kept, but NOTHING IS REBUILT NOW -- no
`render_style_changed` -- so the picture on screen keeps its look until the
next one is built (the next system, the chart's next build, LOCAL's next
setup), which draws `s`. Jon: the picture holds its brightness; a style
switched under a still view read as the whole frame dimming by itself
(RADIANT's light through gas gone at once, 16.9 to 13.2 in a frame).
```

## Retina cap

Above `const RETINA_MAX_SCALE := 2`:

```text
RETINA STOPS AT 2X (Jon, Oct 27, ruling C2). Godot counts a Mac's screen in
pixels, which on Retina are twice its points: the default "looks like
1440x900" is 2880x1800, the largest window that fits is 3X (2880x1620), and
the shell drew about four full-window passes over those 4.7 million pixels
every frame (Oct 27). On an Intel MacBook's graphics that was estimated at
3 to 5 ms a frame (never measured), against 1.5 to 2.5 at 2X: 1920x1080, 56%
fewer pixels, and a picture two thirds of the screen wide. So on a Retina Mac the
window stops at 2X: the first launch opens a 2X window, WINDOW SIZE offers
nothing bigger, and a saved 3X window opens at 2X (`apply` clamps it, and
saves it, because 3X is no longer a size the row offers). BORDERLESS and
FULLSCREEN still fill the screen (`GameShell._fit`). Windows and Linux are
untouched: only macOS is asked.
```

## Borderless window

Inside `apply()`, above `DisplayServer.window_set_size(extent + Vector2i(0, 1))`:

```text
ONE PIXEL TALLER THAN THE SCREEN, and that pixel is the whole point.
A borderless window sized EXACTLY to the screen is what Windows
calls a fullscreen optimization: it hands the display over on every
focus change, which is the black flash when you click out to
another monitor and back. A window a pixel past the bottom edge is
an ordinary window to the compositor and still covers everything.

TALLER, NOT SHORTER: the viewport scales by whole numbers, so a
window one pixel SHORT of 1080 would drop the game from 2x to 1x.
```

## First launch

Above `static var first_launch_in_harness := false`:

```text
THE FIRST LAUNCH'S WINDOW, when there is no settings file at all (an
existing file is never overridden). A window is a whole multiple of 960x540
and has to leave room for the title bar and taskbar, so on a 1080p screen
the biggest one is 1x: a quarter of the screen with every pixel at half the
size the game is drawn for. That was a fresh profile's first sight of the
game (release check, Oct 18; Jon: "A"). So: BORDERLESS (the whole screen,
2x on 1080p) when a window could only be 1x there, otherwise a window at the
largest size offered (`max_window_scale`: 2X on a Retina Mac, Oct 27, where
3X used to fit). Not under a harness (`TestRun`): its scratch
settings file is always new, and its windows keep the size they had --
unless it sets `first_launch_in_harness` to test this (`-- menutest`).
`top` stands in for the screen's largest window scale in that test.
```

## Launch window

Above `static func in_launch_window() -> bool:`:

```text
THE LAUNCH WINDOW (Jon, Oct 20: "not full screen, just like a small window
in the center of the screen"). project.godot opens the game in a small
borderless window on the primary screen, holding the boot splash while the
scripts load, and `apply` then gives it the player's own mode and size.
Whether the window is still that one: borderless, as the project opened it.
(A `--resolution` the size of the screen makes Windows report a borderless
window as fullscreen, so the mode is not part of the test.)
```
