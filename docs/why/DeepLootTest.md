The reasoning behind `tkg/scripts/sim/DeepLootTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Deep loot checks

Above `var h := Harness.new()`:

```text
GOING DEEP PAYS (Jon, Oct 22: a hard game, where going deep is worth it).
  godot --headless --path . -- sheet=DeepLootTest [seed N]

Two rules, and the rarity mix they leave, by tier (`MapGen.tier`):

  1. THE MATERIAL GATES ARE THE MODULE GATES. Materials read danger through
     `MapGen.tier` as `LootGen.roll_module` does: Epic from tier 3, Legendary
     and Artifact from tier 4. They used to compare those tier numbers against
     RAW danger (1-10), so they opened about twice as shallow as modules.
  2. NO COMMON PAST HALFWAY. From tier 3 (danger 5+) no source rolls a COMMON
     module or a common material -- and a pool the rule would empty falls back
     to the same pool with its commons, never to one hard-coded part.

Every source rolled the way the game rolls it, over SEEDS seeded galaxies:
every wreck a fight could leave (`Combat.roll_wreck`), a kill bag
(`Run.open_bag`), a derelict's parts (`Router`'s salvage roll), an event's
floor part and the relic analysis (`LootGen.roll_module`), every station shelf
(`StationScreen._stock_up`), the custodian's body (`Combat.core_body`), and
every material table (`MaterialTable.roll`). The tables it prints are the
rarity mix of each, by tier.
```
