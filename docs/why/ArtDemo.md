The reasoning behind `tkg/scripts/sim/ArtDemo.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Looking tool

Above `const ART_DIR := "res://art/sprites/modules/"`:

```text
Every part that HAS art, on one ship, live:
  godot --path . -- artdemo

A LOOKING TOOL, not a test. `-- artcheck` answers whether an asset is the
right size and `-- shipshot` photographs one hull; neither answers the only
question that matters while art is being made, which is whether the thing
looks right on the ship with a hand on the mouse. A fresh run installs
whatever the starter kit says, so most of the parts being drawn are simply
not on screen to be judged.

So this fits the drawn ones deliberately, and puts their cards in the deck.
Zoom with the button over the hull, drag to pan, hover a module in the right
panel to light it up on the hull, F to flip a fitted part.

It reads the SAME LIST the coverage gate does — anything with a file in
art/sprites/modules is fitted here — so a part drawn tomorrow needs no edit
to this file to be looked at.
```

## Reactor opened

Inside `run()`, above `Run.hull.reactor = 999`:

```text
AND THE REACTOR IS OPENED UP. install_module shuts down the cheapest fitted
part until the new one can be powered, so five real modules on a tier-0
medium quietly cost you the mass driver — which reads as "the sprite is
broken" and is actually the ship being honest about its power budget. A
looking tool has no business simulating that, so it does not.
```

## Turned parts

Inside `run()`, above `if "turn" in argv or "hold" in argv:`:

```text
`-- artdemo turn` STANDS EVERY LONG PART ON END IN THE HOLD, which is the
only place a part can be turned at all: `turned` is a PACKING decision and
the hull's mounts never see it. So fitting the drawn parts is not enough to
reach the case -- they have to be STOWED, which is why this puts a copy of
each into cargo rather than turning what is already bolted on. Turning
`Run.installed` and repacking looked right, printed "stood 3 parts on end",
and changed nothing on screen, because repack_hold walks `Run.cargo`.

The bug it exists to show: a turned part keeps its footprint and swaps its
axes, and for a while the ART did not swap with it -- a stood-up gun kept
drawing lengthwise and ran straight through both its neighbours.

`-- artdemo hold` stows them without turning, which is the before picture.
```

## Arrive by sector

Inside `run()`, above `if "sector" in argv:`:

```text
`-- artdemo sector` ARRIVES BY WAY OF ANOTHER SCREEN, because a screen that
replaces one already up is not the same screen as one built into an empty
root -- the outgoing one is still holding its size while the incoming one
asks for its own, and anything measured during that is measured early.

Added chasing a report that the ship slid sideways when a part moved in
the hold, on the theory that arriving from the sector left the hull view
placed against a stale width. IT DID NOT: the clip measured 431 on every
frame from the first, and the real cause was a pan flag left set by an
earlier press. Kept anyway -- arriving the way a player arrives is worth
being able to do, and the next layout bug will want it.
```

## Shot mode

Inside `run()`, above `if "zoom" in OS.get_cmdline_user_args() and Router.current is ShipScreen:`:

```text
`-- artdemo shot` PHOTOGRAPHS IT, because a looking tool nobody can
measure is a looking tool that gets argued about. `-- shipshot` cannot
serve here: it photographs the STARTER ship, which carries none of the
parts being drawn, so every card in its panel falls back to a glyph and
a reading taken off it says nothing about the art at all. That mistake
cost an afternoon.
`-- artdemo heavy s zoom shot` photographs the tight case ZOOMED, which is
where a long part runs out of window. Settle first: the zoom retimes the
clip and the mounts, and a shot taken during that is a shot of the
transition rather than of the result.
```
