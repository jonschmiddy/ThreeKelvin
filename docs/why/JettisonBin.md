The reasoning behind `tkg/scripts/ui/JettisonBin.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Jettison hatch

Above `signal dumped(item: HoldItem)`:

```text
The hatch. Drag something onto it and it goes overboard.

Right-clicking an item already does this and will keep working -- see
`ItemIcon._gui_input` -- but a right-click is a thing you have to be told
about, and nothing on the ship screen was telling you. A hatch beside the
hold is the same instruction drawn instead of written.

It puts things on the SYSTEM'S FLOOR, not into a wreck: this is the ship
page, there is no container open, and `RunState.jettison` is exactly the
"no screen open to say where you meant" case. What you drop here is
recoverable from SECTOR LOOT for the rest of the run. A system is a place
you can leave things; the price of coming back for one is the trip.
```

## Hatch states

Above `var _armed: bool = false`:

```text
Awake while something of YOURS is in the air anywhere on screen.

Three states rather than two, and the third is the one that was missing: a
control that is always red is always shouting, and a red cross beside a hold
you are not touching reads as a warning about the hold. Grey until there is
something it could act on.
```

## Hatch mark

Inside `_draw()`, above `var pad := 5.0`:

```text
A SQUARE WITH A RED CROSS, and the plainness is the point.

This has been a hatch with jaws (read as a face at 56px) and then a hatch
with an arrow through it (legible, and still a small diagram you had to
work out). A cross is the one mark nobody has to read -- it means the
thing under it stops -- and red is the only colour in this palette that
has never meant anything else.
```
