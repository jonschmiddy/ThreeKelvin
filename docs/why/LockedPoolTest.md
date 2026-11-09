The reasoning behind `tkg/scripts/sim/LockedPoolTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Locked manufacturer pools

Above `var h := Harness.new()`:

```text
A LOCKED MANUFACTURER APPEARS NOWHERE (Jon, Oct 20: "Solari things should NOT
show up in the game until Solari is unlocked (win the game once)").
  godot --headless --path . -- sheet=LockedPoolTest [seed N]

Three profiles, each over SEEDS seeded galaxies, every source of a part or a
hull rolled the way the game rolls it:
  - every wreck a fight could leave, at every system, for every ordinary kind
    (`Combat.roll_wreck`, Territory space forcing its manufacturer included);
  - every station's shelf and its yard hull (`StationScreen._stock_up`);
  - a kill bag at every system (`Run.open_bag`), a derelict's hull and an
    event's hull (`LootGen.roll_hull` off the salvage stream), the derelict
    hauler's frame (`OptionTable.derelict_frame`, rolled where it lies), the relic
    analysis and an event's floor part (`LootGen.roll_module`, both ways);
  - the custodian's body at the core (`Combat.core_body`);
  - every contract board's fetch item (`Contracts.board`).
A FRESH profile (no record, developer mode off) finds Korvan and unbranded
and nothing else, and every one of those still rolls something; a record with
a Korvan WIN finds Solari too and nothing past it; DEVELOPER MODE finds Solari
too. No profile finds a manufacturer `DB.ACTIVE_MANUFACTURERS` leaves out.

Then the two ways a run could change its mind: a save from a fresh profile
loaded after a Korvan win is recorded still finds no Solari (and the next new
run does), and in a party the host's unlocks are the world's.
```
