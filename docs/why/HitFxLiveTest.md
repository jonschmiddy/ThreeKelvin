The reasoning behind `tkg/scripts/sim/HitFxLiveTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hit fx test

Above `var h := Harness.new()`:

```text
HITS, BLOCK AND BRACE IN A REAL FIGHT (Jon's picks, Oct 13: hits B, the
bubble, brace I).
  godot --headless --path . -- sheet=HitFxLiveTest
Through the real SectorScreen, a pack of three: every enemy and your ship
carry their `HitLayers`; and for each kind of landing, its visual --
  block gained: the bubble up with that block (an enemy's and yours);
  brace gained: the plated overlay's panels clamped on;
  a shot the block soaks: the bubble takes it, still up;
  a shot that empties the block: it fizzles;
  a shot into the brace: the overlay takes it, sheds panels in proportion;
  a shot into the hull: a mark (the marks' version moves);
  the turn's end: your leftover block fizzles;
then a kill: the dead slot's wreck is cut from the picture WITH the marks
(EnemyArt's marked wreck, keyed where it lies), and LOCAL's wreck slot at that
place draws the same picture. Headless, so every landing lands at once.
```
