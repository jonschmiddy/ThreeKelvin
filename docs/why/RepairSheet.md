The reasoning behind `tkg/scripts/sim/RepairSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Repair worth

Above `const LIFELINE := 0.20`:

```text
What every repair card is actually worth, and when:
  godot --headless --path . -- repairs

`heal_scale` is a dial you cannot read off the data. A card printed as "heal 2"
that scales at 4 is worth 2 on a turn you are fine and 10 on the turn you are
about to die, and the whole design question — IS THIS A LIFELINE — is a
question about the second number, which appears nowhere in Database.gd.

So this prints the second number. Three columns: full hull, half hull, and
three hull left, against the three real weight classes rather than a made-up
one, because a card that saves a heavy does not necessarily save a light.

The bar it is checked against: at three hull, ONE CARD FOR AT MOST ONE ENERGY
should buy a turn. Anything under that is a repair card, not a lifeline, and
the difference is the entire reason the field exists.
```
