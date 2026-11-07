The reasoning behind `tkg/scripts/sim/AudioTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Audio test

Above `var _tree: SceneTree`:

```text
The music picks the right cue, loops without a gap, and leaves nothing behind.

  godot --path . -- audiotest

NOT HEADLESS, and for once not because of `frame_post_draw`. `Audio._ready`
disables itself outright on a headless run or under `-- sim`, so the whole
subject of this test does not exist there: it would pass by measuring
nothing, which is the failure this project keeps finding in its own checks.

WHAT IT GUARDED BEFORE, AND WHY THAT IS GONE. The previous edition built a
cue out of six stems and loaded them on first use, and nothing released them
-- a session that touched five places held all five decoded, at 17 MB each.
That whole mechanism has been replaced by finished cues, one file
apiece, played on two voices. There is no cache to leak, so the leak test is
replaced rather than kept: what can go wrong now is picking the wrong cue,
repeating one, stranding a voice, or a loop that does not come round.
```

Inside `run()`, above `tree.root.gui_disable_input = true`:

```text
DEAF TO THE DESK. This runs in a real window, and a window that takes a
key takes TAB -- which cycles ship, sector and chart, and every one of
those asks for run music. A keystroke meant for another program swapped
the cue under the test and failed it at random, one run in three while
anyone was typing. The test drives Audio directly; it wants no input.
```

## Cue table

Inside `run()`, above `var named: Dictionary = {Audio.TITLE_CUE: true, Audio.BOSS_CUE: true,`:

```text
---- the table itself, before anything plays

EVERY CUE THE GAME SHIPS IS REACHABLE. Six of the thirteen cues in the old
edition were unreachable for a year because the table that chose them
named seven places and there were thirteen pieces. Twenty-seven files is
a lot of work to leave unplayed, so this counts them rather than trusting.
```

## Loop

Inside `run()`, above `var loops_ok := true`:

```text
---- the loop

THE ONE THING GODOT CANNOT DO FOR US. Its ogg import says where to jump
back TO and not where to loop FROM, and every cue carries six seconds of
reverb tail past its last bar -- so stream looping would play that tail
before every downbeat. `_relay` loops instead, and the tail rings over the
new head, which is what it was printed for.
```

Inside `run()`, above `Audio.music_state(&"gameover")`:

```text
---- the one cue that must NOT loop

Lights Out is fifty seconds of music and twenty of written silence. Relayed
like every other cue, a death would restart its own elegy every seventy
seconds for as long as the game-over screen sat there. So it is sought past
its loop point and the loop watcher is run by hand, and it has to leave it
alone.
```

## Room levels

Inside `run()`, above `var off: Array = []`:

```text
EVERY ROOM LANDS WHERE IT IS MEANT TO, IN LUFS. The levels are derived --
target minus the file's own measurement -- never chosen, so the mistake the
table invites is editing one by eye. It re-does the arithmetic instead.

IN LUFS AND NOT RMS because RMS was wrong about the blue room: Jon heard it
as louder than the other two stars while it measured the same, and the
broadcast measure agrees with him by 6.2 dB. Checking in RMS would read the
correction as the fault.
```

## Station announcements

Inside `run()`, above `Audio._load_pa(&"amb_station")`:

```text
---- the station talks, in a different order every time

THE OLD CHECKS WERE ABOUT A TIMETABLE. Six announcements were baked into
the bed at fixed offsets and the music ducked by comparing the playhead
against a table of windows. Jon asked for the order to stop repeating, so
the lines came out of the mixdown and the bed no longer says anything: the
game deals them. What has to be true changed with it.
```
