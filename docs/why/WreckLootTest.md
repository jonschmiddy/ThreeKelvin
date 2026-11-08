The reasoning behind `tkg/scripts/sim/WreckLootTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Wreck loot

Above `var h := Harness.new()`:

```text
EACH WRECK HOLDS ITS OWN SHIP'S LOOT (Jon, Oct 13: "Each ship you kill has a
chance to get credits and modules and other parts").
  godot --headless --path . -- sheet=WreckLootTest

Five claims, each one a way the per-wreck roll could quietly be wrong:
  - a won fight's wrecks each hold what THEIR OWN template rolls at their own
    place, and the victory line says what they hold;
  - the credit chance and the amount stay inside their bounds over thousands
    of wrecks, the Hellbender always pays its number, fauna pay exotic and no
    money, and the parts follow the table (bigger hulls more, lawless double);
  - a two-ship fight pays about the sum of its two ships, not the last one's;
  - two machines in a party, on different seats with their streams at
    different places, roll every wreck identically, sized for the crew;
  - a save keeps every wreck's contents, and what was taken out of it.
```
