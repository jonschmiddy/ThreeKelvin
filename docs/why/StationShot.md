The reasoning behind `tkg/scripts/sim/StationShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station shot

Above `func run(tree: SceneTree) -> void:`:

```text
The station, photographed. `godot --path . -- stationshot [manufacturer=solari]`

Same reason ChartShot and ShipShot exist, and one more besides: `-- station`
opens this screen but nothing has ever taken a picture of it, so the busiest
screen in the game is the one every change to it was judged on by memory. The
header alone carries two documented layout disasters -- an autowrapping label
that collapsed into a column, and a non-wrapping one that grew the screen to
983 pixels inside a 960 window -- and both were found by looking.

NOT HEADLESS. The dummy display server never emits `frame_post_draw`, so a
headless run of this hangs and looks exactly like a crash.
```

## Berth flags

Inside `run()`, above `var berths: Array[StringName] = [&"solari"]`:

```text
`manufacturer=none` photographs a station NOBODY holds, which is the case the
header has to get right by omission rather than by drawing -- lawless space
has no berth, and a blank flag there would read as a manufacturer with no
mark instead of as an absence of manufacturers.
A COMMA LIST, because a station can be held by up to THREE and the rail
sizes its flags to how many are flying. `MapGen` wants three on 35% of
cities and 60% of capitals, so the contested case is common -- and it is
exactly the case no amount of clicking will reliably reach, which is what
this tool is for.

  manufacturer=solari              one berth
  manufacturer=solari,cygnet       contested
  manufacturer=solari,cygnet,korvan   three, at the smaller flag
```

## Fit flag

Inside `run()`, above `for a8 in OS.get_cmdline_user_args():`:

```text
`fit=full`: every hardpoint the hull has, filled with its own manufacturer's
parts, to see how a fitted hull reads -- `manufacturer=korvan` for the
manufacturer whose parts are all drawn. `fit=full:heavy:3` refits the
chassis first, at that weight and grade. Couplings go on first, since a
part that raises the reactor makes room for the rest; then the smallest
draw, different parts before repeats, and only what the reactor will run:
a ship a player could fly.
```

## Full flag

Inside `run()`, above `if "full" in OS.get_cmdline_user_args():`:

```text
`full` PHOTOGRAPHS THE BUSY CASE, the same one `-- station full` plays.

Without it the Yard's hull is a 75% roll and the shelf is whatever the node
happened to stock -- so one shot in four of the shipyard is a picture of
the empty-berth line, and a shot of a full shelf is luck. The odds are
balance and are left alone; this forces the state, exactly as the playable
flag does.
```

## Moving day

Inside `run()`, above `for a in OS.get_cmdline_user_args():`:

```text
`-- stationshot full moving` photographs MOVING DAY: the state one click
after TAKE IT, with both ships drawn and the leftovers still on the old
one. Reached by actually buying the hull rather than by posing the screen,
so what the shot shows is what the flow produces.
`-- stationshot full ship=BLUEBIRD` flies a NAMED ship.

A custom name is the one piece of state no fixture reached, and it is
exactly the state that catches a screen printing `hull.name` where it
should print `Run.display_name()` -- which the Shipyard's own berth label
was doing until this flag showed it.

SET BEFORE THE SCREEN IS BUILT. Parsed after `show_station` the first time,
which proved nothing at all: the deck had already drawn itself off the old
value and no refresh had been asked for.
```

## Deck flag

Inside `run()`, above `for a in OS.get_cmdline_user_args():`:

```text
`-- stationshot full deck=hold` photographs a deck other than the one the
screen opens on. The rail is a lift and clicking it is the only way in, so
without this every shot of this screen was the SERVICES deck and the other
four could only be looked at by playing to them.

  deck=services  deck=work  deck=stock  deck=hold  deck=bench
```

## Lab deck

Inside `run()`, above `if deck == &"bench" and not scr0._tabs_on.get(&"bench", true):`:

```text
EVERY STATION HAS ITS LAB since Jon's Nov 3 ruling (all five decks at
every level), so this never fires today. It used to: a lab below a city
had no recipe and its deck was shut. Kept as a guard, so a deck that is
ever shut again can still be photographed, and says so when it does.
```

## Tape flags

Inside `run()`, above `for a12 in OS.get_cmdline_user_args():`:

```text
`labtape=<path>`: the Laboratory's power-on as the game plays it, heard rather
than seen -- every sound Audio really plays in the 4.5 s after the lab powers
on, as [name, seconds after power-on], written to <path> as json. The lab's
clock has to run for it (no labclock=); what it hears is POWER_ON_SOUNDS
through Audio.play, rate limits and all. Needs a window: without one Audio
is off and the tape stays empty.
```

Inside `run()`, above `for a23 in OS.get_cmdline_user_args():`:

```text
`boardav=<dir>`: the Hiring Board seen AND heard, as a player gets it: the
station picked by `avseed=N`, powered on from dark, for `avsecs=S` (24)
seconds -- every frame of the board, with when it was drawn
(`frames.json`), and everything the game played on its master bus
(`audio.wav`), music and station included. On a screen, a popup is
clicked shut 2.5 s after it opens, as a player would. Needs a window.
```

Inside `run()`, above `for a14 in OS.get_cmdline_user_args():`:

```text
`yardtape=<path>`: the Shipyard heard -- every sound the game plays for
`yardtapes=S` seconds (12) after its TV powers on, as [name, seconds after
power-on], on the yard's own running clock (no `yardclock=`). The TV's
power-on, the bed, the drones flying in and at work (`yardbuy=I:S` buys as
a click does), the welder, the now-and-then, a light's flicker. Needs a
window: without one there is no sound.
```

## Audio capture

Inside `run()`, above `var cap23 := AudioEffectCapture.new()`:

```text
A CAPTURE, NOT A RECORD: AudioEffectRecord hands back silence here (4.7,
WASAPI, added at run time) though the master bus meters -6 dB. The
capture's ring buffer is drained every frame instead, into `pcm23`.
```

Inside `run()`, above `var pairs23 := int(AudioServer.get_speaker_mode()) + 1`:

```text
ONE BLOCK PER SPEAKER PAIR: on a 7.1 output the master bus is four stereo
pairs, and the capture is handed each pair's 512-frame mix block in turn
(front, centre, rear, side). The front pair is what plays on stereo; keep
it, drop the rest, or the sound runs four times too long.
```

## Measured slab

Inside `run()`, above `await RenderingServer.frame_post_draw`:

```text
THE SLAB'S OWN HEIGHT, printed rather than eyeballed.

It sat at 293 for 189 of content -- a hundred pixels of nothing
under the last perk -- because `set_anchors_and_offsets_preset`
writes the CURRENT rect into the offsets and nothing had corrected
`offset_bottom` since. A screenshot shows you a panel looks empty;
only this says by how much, and against what it should be.
```

## Bar width

Inside `run()`, above `if Router.hud != null and Router.hud._row != null:`:

```text
THE BAR'S OWN WIDTH, printed rather than eyeballed. HudBar's header records
that the row was 983px at a 960 window with dev mode on, and that the fix
was four pixels of separation per gap -- so anything added to it since is
spending a margin measured in single figures. A screenshot shows you the
last tab is short; only this says by how much.
```

## Buy and sell

Inside `run()`, above `if "buy" in OS.get_cmdline_user_args():`:

```text
`-- stationshot full deck=stock buy` BUYS A PART THE WAY A PLAYER DOES:
a real pick-up off the rack, handed to the counter, and the run checked
after. The rack is scaled by two and the counter stands where the room
puts it, and neither is anything `fittest` reaches. The drop is handed to
the counter directly for the reason `FitTest._carry` gives: Godot follows
the OS cursor once a drag is live, and warping the real mouse is not a
thing a test should do to the machine running it.
```

## Sky flags

Inside `run()`, above `for a9 in OS.get_cmdline_user_args():`:

```text
`skyview=<path>`: THIS STATION'S SKY at backdrop size, 800x400 -- the
planet it orbits and its stars, as the sector draws them -- for the
Exchange's bench to hang behind its windows. `skyseed=N` borrows node
index N for the roll, so five levels can show five different skies
without moving the station anywhere. `skyseed=3,9,14` rolls several in one
run, each to the path with `{seed}` replaced; `skysize=740x431` draws the
sky at the size of the room's wall, the way the Exchange hangs it, and
`skyframe=x,y,w,h` frames its world in that rect of it, as the Exchange
frames it in the room's biggest window. `skyparts` also writes the sky
without its world (`<path>` with `_stars` before `.png`) and the world
alone at the size it is drawn (`_body`), for the bench to frame live.
```

## Clip flags

Inside `run()`, above `for a13 in OS.get_cmdline_user_args():`:

```text
`yardclip=<dir>`: the Shipyard as a run of frames on its own clock,
`clipframes=N` (90) `clipms=M` apart (66), from `clipfrom=S` seconds after
its TV powered on (0) -- the power-on, the drones flying in, anything
`yardev=` fires. `yardbuy=I:S` buys service I at S seconds, as a click does;
`yardbuy=take:S` presses TAKE IT, and the clip goes on with the dock open
over the yard; `yardbuy=backout:S` presses the dock's BACK OUT.
```
