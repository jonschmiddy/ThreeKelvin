The reasoning behind `tkg/scripts/sim/FoeTagTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Foe tag checks

Above `var _fails := 0`:

```text
WHAT AN EVENT'S FIGHT BRINGS IS WHAT ITS TEXT SET UP, headless:
  godot --headless --path . -- sheet=FoeTagTest [seeds=N]

Jon, Oct 17: a fight started from an event's choice may bring a creature,
"but the text leading up to the fight should make sense. Like it should
mention the megafauna or whales you know?" The rule is data: an option (or
one of its choices) carries `foe = &"whale"` / `&"leviathan"` when its text
is about that creature (`OptionTable.fight_foe`), and `Router.option_foe`
fields exactly that, or a ship off the ordinary pool when there is no tag.

Three parts:
  1. THE TABLE. Every tag names a creature, sits on a fauna-gated option that
     can actually start a fight, and its body names that creature (a calf
     event says "calf", a leviathan event "leviathan"). Every untagged option
     that can start a fight has no creature in its body.
  2. THE SWEEP, over N seeded galaxies (default 24): every fight-capable
     choice of every option rolled at every system, asked of the same door
     the game asks. A creature exactly when the option is tagged, and the
     creature it named; a ship otherwise, fauna space included. Then the
     same sweep against two broken builds -- the tag dropped on the way to
     `option_foe`, and the old rule that took fauna from the region -- each
     of which must be caught, so this check is known to see the fault.
  3. THE DOORS. Each creature event and two ship events opened on the real
     LOCAL, its fight choice taken through the event band
     (`LocalEventDrawer.choose`, `OptionResolve.take`), and the fight that
     `Router.start_ambush` opens read off `Router.combat`.
```
