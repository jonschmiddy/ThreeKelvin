The reasoning behind `tkg/scripts/sim/SystemShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shot options

Above `const ScreenS := preload("res://scripts/ui/sysmap/SystemMapScreen.gd")`:

```text
The system map as the game shows it, photographed:
  godot --path . -- sheet=SystemShot out=<png> [seed=N] [node=I] [at=S] [hover=b|w|s] [select=I]
`hover=b` points at the first beacon, `w` at the first world, `s` at the star;
`select=I` selects body I (-1 the star) and shows it in the panel; `open=K`
opens the K-th beacon in the panel; `take=J` then takes its choice J (through
`OptionResolve`, as LOCAL's band does: the map no longer takes choices) and
shows its page stamped. Needs a window.
The panel's states (the event list Jon picked, B with the stamp):
  `takes=i:j,i:j`  takes option i's choice j, in order, before anything is
                   shown -- walk-aways included -- so the list wears its stamps
  `partner=i`      a partner, VEGA, claimed option i (and closed its set)
  `hovercard=K`    points at the K-th card in the list
  `hoverbeacon=K`  points at the K-th beacon on the map
  `hoverchoice=J`  with `open=`, points at choice J on the event page
`take=J` parks the ship at the event's world first, so the clock need not run.
`job=fetch|hunt` signs the first such contract and shows its target, with
the work on the map.
THE WEATHER (`SkyWeather`), filmed with `wclip=<dir>` (see `_wclip`):
  `sky=<key>`      the first system whose sky is emission, reflection,
                   planetary, remnant, dark, calm, pulsar or core; `shape=0..3`
                   narrows a planetary one, `star=RED|BLUE|ORDINARY` a calm one
  `wlist`          the sky, its temperament, its favourite and its events
  `wprobe`         a mark at every point the weather's ported noise finds
TWO SUNS AND HEAVY GIANTS (ruling 20, Oct 30):
  `twin`           the run's first two-sun system, the busiest (most bodies, a
                   giant first); with `-- twin=all` every ordinary system is one
  `twinnth=K`      with `twin`, the K-th such system instead of the busiest
  `giantsys`       the first one-sun system with a giant (every giant now
                   weighs 1/10 to 1/4 of its star; prints its weight)
  `park=I`         the ship in orbit of body I (default 0; `noship` at the edge);
                   `park=wa` / `park=wb` the world round star A / star B
  `focus=wa|wb`    the camera held on the world round star A / star B
  `look=a|b`       the camera held on star A or star B at the zoom given
and prints the pair (star B's place, radius, share, each body's centre).
`at=S` is the map's clock the still is taken at (30 s if not given): a pair
turns on it (ruling 23), so it is the pair's angle too, printed with it.
```

## Flown ship options

Inside `_ready()`, above `for a5 in OS.get_cmdline_user_args():`:

```text
THE FLOWN SHIP. `shipfree=x,z,vx,vz` puts it free on the plane, moving, so its
dotted line shows; `keys=w,d` holds those keys and `run=S` runs the clock S
seconds (with them held); `again=I` selects place I and clicks it again, and
the clock runs until the ship is in orbit there; `selectonly=I` selects it
and stops, so the flight a second click would fly is drawn; `hoverbelt`
points at the first belt's band.
```

## Zoom then pan

Inside `_ready()`, above `for a17 in OS.get_cmdline_user_args():`:

```text
`zoompan=<dir>` (`zpz=Z`, `zpv=PX`): THE MAGNIFICATION CHANGED, THEN A PAN
(Jon: "If I change the magnification on painted and then pan left or right I
get some lag in the nebula"): the wheel's target set to Z and eased by the
screen as play eases it, 40 frames, then at once a pan of PX a frame for 90,
on a stopped clock. Every frame saved, with its time, the zoom, the pan and
the cloud's slide (`SystemView.neb_off`) in `zoompan.json`. `zpback`: no
pan, the zoom sent back out at frame 65 instead (in, still, out, still).
```

## Weather filming

Above `func _wclip(scr: Control, wdir: String) -> void:`:

```text
`wclip=<dir>`: THE WEATHER, FILMED. The map window saved each frame, the
weather stepped a 30th of a second a frame (`wfps=60`: a 60th), and with it
every clock that moves the picture -- the map's (the worlds, the stars'
twinkle, the pulsar's beat with its sound stopped), the gas's churn and the
supernova's -- so a clip and its baseline differ by the event alone.
  `wev=<name>`   that event, forced ten frames in, once the palette is a
                 second old; `wev=none` films the baseline; no `wev`, the
                 system's original weather (today's `wclip`)
  `wframes=N`    how many frames (for a named event: all of it and a second)
  `wat=x,y`      where, in from the map window's top left
  `wfreeze`      the clocks held still, only the event moves
  `wup=0`        today's version of an upgraded event
  `wreduce=N`    reduced motion switched on at frame N (the event should be
                 gone the frame after)
Writes `f_NNNN.png`, `peak.png` (the frame at the event's height) and
`meta.json`: for each frame the event's age and where the ship, the labels,
the worlds and the star are, in the saved picture's pixels.
```

## Weather scheduler

Above `func _wrun(scr: Control, secs: float) -> void:`:

```text
`wrun=S`: THE SCHEDULER AT WORK, as the game runs it -- its own picks, its own
placement against the real map, the supernova on its own clock too -- for S
seconds on a fixed step (`wfps=`, default 10 a second, so minutes take
seconds), the ship parked and no input (no idle pull unless `widle`). Prints
every start, the rate per tier a minute, how much of the time something is
live, and any moment two things overlap that should not: a showpiece with a
supernova or with a small event, or a supernova over a far-sky event.
`wrunshots=<dir>` saves the window every `wrunevery=` frames (default 10).
```

## Scroll bar check

Above `func _scroll_check(first) -> void:`:

```text
THE SCROLL BAR COVERS NOTHING (`scrollcheck`, headless, in the gate). Jon,
Oct 20, on the WORLD card: "the scroll bar covers up text" -- "3.54 G",
"FROZEN", "H2 HE" and "NONE" ran under the bar, because the page's own
pieces asked for more width than the panel has once the bar takes its share,
and a ScrollContainer that cannot scroll sideways lays its content out at
that width anyway and clips it under the bar.

Over the run's first `scrollsystems=` systems (40), the sector's list and
every world's page, each unscrolled and scrolled to the end: no text and
nothing that takes the mouse, where it shows in the panel, may meet the
bar's rect. Prints the world with the widest row of facts (label and value,
in the panel's type), which is among them. A pass that never saw a bar has
measured nothing, so pages must scroll.
```

Above `func _scroll_leaves(root: Node, out: Array) -> Array:`:

```text
Every text and every mouse-taking control under `root` that is showing, as
[control, the rect it puts its words or itself in].

A one-line label's words are only as wide as they are, set by its alignment
(an eyebrow's rect runs the panel's width with its words at the left); a
wrapped label or a rich one can reach its whole width, and so can a button or
a card that answers the pointer.
```
