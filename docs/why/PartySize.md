The reasoning behind `tkg/scripts/sim/PartySize.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test purpose

At the top of the file, under `extends Node`:

```text
THE PARTY-SIZE TABLE (Jon, Nov 5): what `PartyScale` makes of a fight for 1
to 4 players, measured, not guessed.

  tools/dev/godot.sh --headless --path tkg -- sheet=PartySize [runs=150] [seed=N]
      [h=1.0] [sweep=0.6,0.8,1.0,1.2] [enemy=cutter] [n=1,2,3,4]

N ships in one process. `Run` is one ship, so each ship keeps its own hull,
heat and death in a snapshot swapped into `Run` before it acts (all fly the
same Korvan medium starter kit, so nothing else on `Run` differs). Each ship
has its own real `Combat` (deck, hand, energy, block, brace, drones,
charges), planned through `Combat.plan` with the party's count, so the hull
is the game's own (`PartyScale.hull` in `_spawn`); all point at ONE enemy
list, as a shared fight has one enemy. Cards are played by the sim's
`Policy`. The enemy's turn is the host's (`NetSession._swing`): each live
hull picks a target weighted 0.5 + heat ratio, and the hit resolves on that
ship's Combat (`_act_one`: dodge, block, brace), as `_on_swing` does.

Two rows per party size:
  party  every player in the fight from turn 1
  alone  one ship fighting a fight built for the whole party (the global
         rule: the others are elsewhere)
`h=` overrides `PartyScale.HULL_PER`; `sweep=` prints the 2-player rows at
each value given, for picking it.

The Custodian lens: a starter kit dies to it in three rounds, so for that
fight every ship gets a bigger hull (`custhull=`, 120), standing in for a
ship built over a run, as `CoJoinMeasure` did (one ship alone wins about
half).
```
