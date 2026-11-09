The reasoning behind `tkg/scripts/ui/SpaceLayer.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## One sky for all

Above `var backdrop: SpaceBackdrop`:

```text
The sky, once, behind every screen.

`SpaceBackdrop` and `NebulaWeather` were built for the encounter view and
constructed inside it, so the one screen that fights had a world behind it
and the ones that do not — the refit bay, the hold, both galleries, the
record, chassis select, the party, the lobby — were panels on
the clear colour. The generator was never the problem. Its only consumer was.

So the pair moves up to `Router`, above the screen that happens to be open,
and a screen swap changes what is IN FRONT of the sky rather than replacing
it. That is most of what "one continuous space" means in practice: the place
does not blink out because you opened your own hold.

WHY IT IS NOT REBUILT PER SCREEN. `SpaceBackdrop.setup()` bakes a world into
an ImageTexture — tens of thousands of pixels of noise — and early-outs on a
node it has already baked. Hosting one layer for the run means that early-out
does its job: the bake happens on arrival, and walking from the refit bay to
the hold and back costs nothing. Rebuilding the pair per screen would put a
world bake on every navigation in the game.

WHERE IT MUST NOT GO. The station decks are interiors and say so in their own
header: "you are inside this thing. Nothing here is drawn from outside, there
is no starfield." A layer that sits behind everything will leak sky into them
unless something turns it off, so `set_active(false)` is not an optimisation,
it is the ruling. `-- stationshot` is the check.
```
