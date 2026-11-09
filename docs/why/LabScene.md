The reasoning behind `tkg/scripts/ui/LabScene.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Lab scene

Above `const LAB_DIR := "res://art/sprites/station/lab/"`:

```text
The Laboratory: one of Jon's five painted labs, lit and running.

IT WAS A ROOM DRAWN IN CODE -- a fume hood, a whiteboard, two culture tanks
-- with the recipes behind the hood's glass. It is one picture per
development level now, each a PixelLab take Jon chose and had edited by hand,
and each lit the way Five Labs, Lit lit it: the artifact he judged them on,
and the reference for everything below. `tools/lab_install.py` installed
them (`art/sprites/station/lab/`) with every light's pool worked out ahead of
time; what happens here is the part that moves.

THREE LAYERS, AND THE RECIPES BETWEEN THEM.

  this node   the picture, lit (`lab_light.gdshader`), and its life: the
              small monitors typing, bubbles in the capital's tanks, the
              flasks on its counter fizzing
  (screen)    the station owner's sign-on (`LabLogin`, `StationScreen`'s),
              standing in the picture's own screen (`win_rect`), and the
              glass's key, clipped to the glass so the power-on's scan can
              bring them up
  fx_layer()  what the big screen does, over the rows: the city's sweep,
              the outpost's and settlement's bad signal, the unclaimed
              screen failing with its bulb, the capital's rim light

ON A 30 HZ CLOCK, like the shop, because the prototype drew at 30 and every
fault was shaped for that rate. Each lab powers on from black the first time
you step onto the deck at a station: the lamps strike, the room fades up,
the screen scans its sign-on in -- each with its sound (`POWER_ON_SOUNDS`).

Drawn at 1:1 at the top-left, like the shop's rooms: every lab is the
740x431 wall they were laid out on.
```

## Power-on sounds

Above `const POWER_ON_SOUNDS := {`:

```text
THE POWER-ON, HEARD: each lab's sounds, seconds after power-on, as Jon passed
them on the audition page (Lab Sounds, 2026-09-28) -- a flicker on each of
the bulb's flashes, a click before the screen it wakes, the static on the
frame the rows start to scan in. Each name is one wav in `assets/audio/sfx/`
with its layers already mixed and a static already cut to length, so it
plays at 0 dB and no pitch wander. The times meet the lights in `_weights`
and the rows' `boot.reveal` in labs.json: move one and move the other.
```

## Lab ambience

Above `const AMBIENCE := {`:

```text
THE LAB AFTER ITS POWER-ON, HEARD (Jon: "They're dead silent after the
monitor turns on. Let's make em feel real."): a bed that loops, from
`assets/audio/ambience/`; now and then one of its sounds, dropped in at
random; and on each flash of a light that already stutters (`watch`, the
light and the power-on seconds before it starts), its flicker -- the city's
two ticks in turn. Every level is baked into its file, as Jon set it on the
audition page, and all of it plays on the Ambient bus beside the station's
own crowd and PA, which carry on underneath.
```

## Light rhythms

Inside `_weights()`, above `var n := roundi(tb * HZ)`:

```text
A DEN UNDER ONE BAD BULB: it strikes, then flutters, and every few
seconds it is gone for a frame.
FIVE FLASHES, TO JON'S RHYTHM ("1 .. 2... 3 4 5"): 0.3, 0.6, 1.0, 1.1
and 1.2 s, two frames each, the last holding on, a flicker sounding on
each. It struck at random, nine times, before.
```

Inside `_weights()`, above `var hood := _strikes(tb, 0.3, 0.55, 1.3)`:

```text
THE HOOD STRIKES, the tubes stutter on in turn, the monitors pop --
spaced out (Jon: "space the city sounds out a bit"): the tubes at 1.0
and 1.6, the helix monitor at 2.3 with its neighbours round it.
```

Inside `_weights()`, above `var tank := [_smooth(1.5, 2.3, tb), 0.9 + 0.1 * sin(t * 6.283 / 3.7)]`:

```text
THE GOLD BAR STRIKES, the tanks come up teal, the glass comes on --
each waiting for the last (Jon: "the tanks start even later ... more
of a delay"): tanks from 1.5 s, the monitor at 2.2, the glass from 3.0.
```

## Screen sag

Inside `_anim()`, above `func _sag_with_bulb(t: float, s: Dictionary) -> bool:`:

```text
THE SAG: when the bulb fails (its own fault clock) the screen goes dark
with it, then comes back with a flash and a jolt. `sagEvery` makes it only
the bulb's first blink in each that many seconds -- Jon: "it just flashes
too much" when it was every blink (2026-09-28).
```

## The press hushes the screen

Above `func hush_screen(on: bool) -> void:`:

```text
THE PRESS HUSHES THE SCREEN (`LabZoom`, the camera into the glass): from
the press until the camera is back, the lamps hold steady (`lamps_held`),
nothing new starts on the big screen,
and the bad signal's snow and slips stop at once (they flicker frame to frame
anyway); a sweep, a sag or a rim light already running plays out, fading
with the entry. `on` false lets it all run again.
```
