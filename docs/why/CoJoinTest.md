The reasoning behind `tkg/scripts/sim/CoJoinTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Co-join harness

Above `const CODE_TAG := "[cojoin] code "`:

```text
Two processes, flown the way two friends fly: into one system, into one
fight, and back out again. The co-op playtest of Oct 22, as a harness.

  godot --headless --path . -- cojoin host [relay]
  godot --headless --path . -- cojoin join CODE
  tools/cojoin.sh [relay] [late]

Jon and Kevin, Oct 22: "I couldn't join the fight he was in", "we could not
see each other flying around on the sector map", and where both ships were
drawn together they were "totally on top of each other". `cofight` never saw
any of it, because it PLACES both ships on a node and opens the fight by
hand, and the game stopped opening fights that way when the three node types
became one: a system's hostiles are an option now, and an option's fight was
private. This one goes through the doors a player uses -- the jump, LOCAL,
the SECTOR map, the option's fight, JOIN -- and fails on what they found.

`late`: the host dives alone and flies a jump before the guest has even
typed the code. A friend whose game crashed and who joins back in is that.
```
