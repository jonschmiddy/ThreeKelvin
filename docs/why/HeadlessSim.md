The reasoning behind `tkg/scripts/sim/HeadlessSim.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Headless sim

Above `var runs := 200`:

```text
Headless balance simulator.

  godot --headless --path . -- sim runs=200

This tool is worth as much as the game code. In the web prototype it found
three real bugs (including an infinite draw loop) and a structural map flaw
in minutes. Run it after any balance change.

Driven by Main.gd's sim branch, NOT by --script. The sim reads the Run and DB
autoloads, and Godot only creates autoloads when the project boots normally;
--script replaces the main loop and skips them entirely, so every reference
here would fail to compile.
```

## Strand counters

Above `var policy_gave_up := 0`:

```text
The policy ran out of options. NOT the same as the run ending.

`choose_jump` builds its candidates from `node.links`; the game lets you jump
to anything inside a radius (`reachable_from`), and never consults `links` at
all. So the policy giving up means "no CHARTED link was usable", which is a
much weaker condition than "stranded" -- and it was being counted as one.

Kept alongside `stranded` rather than replacing it, because THE GAP BETWEEN
THEM IS THE SIZE OF THE BLIND SPOT, and that gap is the number that says
whether any of this mattered.
```

## Option accounting

Above `var opts_taken := 0`:

```text
What the pilot did with what each system offered.

`ENCOUNTER_REBUILD.md` 8 names `forgone` as the number the model must be able
to report: an option lost because something else in its GROUP was taken
first. It is the depth curve made visible -- counts stay flat and only the
grouping moves, so if this stays near zero the exclusivity dial is not
actually doing anything.
```

## Run tallies

Above `var looted: int = 0`:

```text
Signature at the moment a fight ENDS, which is the only heat a run ever has
a chance to carry onto the map. If this is near zero the map heat layer
cannot matter no matter what is attached to it.
How many things were taken out of containers across the run. The first
number the sim has ever had for "did the pilot collect", which used to be
true by construction.
```

Above `var fights_n := 0`:

```text
The hellbender. `met` is landings on its system, because the first question
about a roamer is whether a run even crosses its path; the rest is what the
model did about it and what avoiding it cost in salvage.
How long an ordinary fight lasts and what it costs: turns and hull lost per
fight, and how many the model lost outright. Added for the enemy-block fix
(combat polish, Oct 13): a block intent that finally works should make
fights longer, and this is the number that says by how much.
```

## Fight payout

Above `var won_by_pack: Dictionary = {}`:

```text
WHAT A WON FIGHT PAYS, read out of the wrecks it left (Jon, Oct 13: "each ship
you kill has a chance to get credits and modules and other parts"). Split by
how many hulls the fight had: an ambush fields its whole pack, as the game
does, and an option's fight one ship (reinforcements are gone). The set
pieces are counted in the totals and left out of
the split, since they pay by their own rules. `fight_credits` is what fights
put into wrecks (and, for the custodian, the ledger); `credits_taken` is what
the pilot banked from them after looting.
```

## Depth payout

Above `var loot_mix: Dictionary = {}`:

```text
WHAT GOING DEEP PAYS (Jon, Oct 22: a hard game where going deep is worth it).
`loot_mix` is every part and material lying in the run's systems when it
ends -- wrecks, floor piles, bags, taken or not -- by the tier of the system
it lay in (`MapGen.tier`), so the rarity ladder can be read against depth.
The core is left out: the custodian's body is authored, not rolled by tier.
`looted_scrap` is what the parts the pilot took would melt for and
`looted_mat_value` what its materials list at; `credits_in` is every credit
the run gained, from any source, read off `Sig.resources_changed` (every
change to `Run.credits` goes through `add_credits`, which emits it).
`core_fights` / `core_wins`: the ship the run built, against the custodian.
Read-only, like `_tally`: nothing here draws from any stream.
```

## Per-kind table

Above `var by_kind: Dictionary = {}`:

```text
Per galaxy kind: name -> {runs, wins, jumps, kills, systems}.

NOT cleared by `_reset()`. That is called once per batch in the by-chassis
sweep, and a per-kind table wants to span the whole sweep -- fifteen kinds
across twenty-one chassis is already thin, and resetting it per chassis would
leave every cell too small to read.
```

## Economy sampling

Above `var stations_visited := 0`:

```text
THE ECONOMY, which decided more runs than danger did and was invisible.

Fuel and credits both flow through exactly two places -- a station, and the
act of jumping -- so they are sampled by delta around those rather than by
hooking RunState. A harness that edits the game to measure it is a harness
that measures a different game.
```

## Fuel audit

Above `var sturdy := false`:

```text
THE FUEL AUDIT (balance/fuel, Oct 17). `fueltrace=<path>` writes one JSON
line a run: the tank at every departure and arrival, what each jump cost,
what was bought and where the money went, and the two "did fuel bite"
counts -- jumps where a seen, reachable star was too dear, and (human
pilot) jumps where the star it wanted most was. Read by the scratchpad's
fuel_report.py; nothing here changes how a run plays.
```

## Combat study

Above `var _enemy_hp := 1.0`:

```text
THE COMBAT STUDY (Phase 11 step 1, Oct 27; Jeremy: "combat doesn't feel
important"). Every enemy but the boss as multiples of its own: its hull
(`enemyhp=`) and the damage its intents deal (`enemydmg=`), applied to the
templates before any run, so ambush packs, event fights, creatures and the
Hellbender all meet the same numbers. The Custodian keeps its tuned values;
`custhp=` and the rest move it. Off unless given, and never a ruling.
```

## Sturdy lens

Inside `run_sim()`, above `sturdy = "sturdy" in OS.get_cmdline_user_args()`:

```text
A LENS, NOT A PLAYER: hull and heat restored at every arrival, so runs
live long enough for the fuel economy to be what is measured. Today's
pilot dies at ~11 jumps of fights and heat with 92% of the tank unspent,
which says nothing about fuel either way. Never a balance number.
```

## Fight wiring

Inside `run_sim()`, above `policy.fight_cb = _option_fight`:

```text
WITHOUT THIS THE SIM MEASURES A GAME WITH NO COMBAT. Fights live only in
option outcomes now, and Policy has no Combat of its own, so an unwired
`fight_cb` means every hostile line resolves to its prose and nothing shoots
back. It reported 0.2 kills a run before this was connected.
```

## By-chassis sweep

Above `func _run_by_chassis() -> void:`:

```text
Every chassis in the game, `runs` each, reported as a table.

  godot --headless --path . -- sim bychassis runs=500

The ordinary sim rolls a random manufacturer and weight per run, which is
right for "is the GAME winnable" and useless for "is this SHIP winnable" —
twenty-one starts averaged into one number can hide a chassis that never wins
behind six that do. This pins one and repeats it.

Slow on purpose: at 500 each that is 10,500 complete runs. It is a thing you
leave running, not a thing you put in the merge gate.
```

## Pilot generator

Inside `_play_one()`, above `pilot = Rng.derive(&"pilot", 0)`:

```text
The simulated pilot's own generator: one per run, seeded from the run's
master seed. The model is a player, not a place — so its choices replay
with the run, and drawing them does not move what the world rolls next.

NOT derived per jump, which is what this was first. Rng.derive() keys on
a position, and `Run.jumps` is not one: jump_to() returns without
incrementing when a jump turns out to be unaffordable, so two loop passes
could share an index, hand back the same generator and make the same
choice twice. The model wandered laterally in circles and reported 94
jumps a run against a real figure of 66 — a policy bug produced entirely
by seeding a decision on something that was not a place.
```

## Ambush parity

Inside `_play_one()`, above `if arrived and not node.cleared and not node.ambush_rolled \`:

```text
Something followed the heat in, through the SAME function the game
uses. This comment used to claim it was "rolled exactly as Router does
it on arrival" and it was not: Router rolls the pack positionally via
`_roll_foes`, and this picked ONE enemy off `Rng.foe` from a pool that
always passed `false` for fauna. Two implementations, one of them
measuring the other.

AND NOW FIELDED AS THE GAME FIELDS IT, which it was not until Oct 17:
the sim fought the pack's lead alone, with `clears_node` true, so a
won ambush consumed the system and the options it held were never
taken; it rolled ambushes at stations, which never have fights
(`Router.no_fights_at`), and on cleared systems, which `_roll_here`
leaves alone; and it rolled one at the start system before any jump.
Now: the gates of `Router._roll_ambush`, on arrival only, and the
whole `Router.ambush_pack` with `clears_node` false, as
`Router.resolve_current_node` opens it.
```

## Option resolution

Inside `_play_one()`, above `if not node.cleared:`:

```text
WHAT THE SYSTEM OFFERS, taken by the policy rather than by the type.

THE ONLY WAY AN ORDINARY SYSTEM RESOLVES, since the collapse. It used to
run beside FIGHT and DERELICT branches that did the same work off a
label; those are gone and this is what replaced them, fights included --
`policy.fight_cb` is wired to `_fight` below.
```

## Strand accounting

Inside `_play_one()`, above `policy_gave_up += 1`:

```text
F1 -- A STRAND IS WHAT THE GAME SAYS IT IS. This used to call
`check_stranded()` and then increment regardless of what it did:
the counter tracked the POLICY giving up, not the run ending.
`check_stranded` returns void and dies internally, so ask the same
question it asks.
```

## Option fights

Above `func _option_fight(n: MapGen.MapNode, foe: StringName = &"") -> bool:`:

```text
Competent-player model: lock on before attacking, brace against telegraphed
damage, vent before overheating, and never overheat unless it secures a kill.
A fight an option opened, against whatever this system would field.

The ship is `Router.option_foe`, the one `Router.start_ambush` fields when an
option's outcome says "fight": one ship off `Rng.foe` from the danger's
ordinary pool. It was this file's own pick, with fauna where the region is
fauna -- and the game's never is, so in fauna space the sim fought whales
(no money, no parts) where the game fights ships.

`foe` is the event's creature tag (`OptionTable.fight_foe`), as the screen
hands it to `Router.start_ambush`: a creature event's fight brings that
creature, everything else a ship.
```

## Galaxy kinds

Above `func _report_kinds() -> void:`:

```text
What each galaxy kind actually played like.

FIFTEEN KINDS THAT ARE NOT THE SAME GAME. `GalaxyGen`'s header claims the
shape of a galaxy cannot move a jump or a fuel cost; it can and does, because
`MapGen.ring_count()` reads `squash` and `hop_distance()` measures in squashed
space. A Lenticular is a smaller galaxy whose hops are cheaper. So a single
win rate is an average over fifteen different games, and the moment that
variation becomes DELIBERATE -- authored `density` and `reach` per kind -- it
has to be readable or there is no way to tell a tuning change from a roll.

SYSTEMS IS THE COLUMN TO WATCH during the galaxy resize: it is the number
`LAYERS` and `RING_SPACING` move, and the one that says whether a change did
what it claimed.

Sorted by win rate, so the spread is the first thing visible. A kind with a
handful of runs is noise -- the count is printed so it can be discounted.
```

## Economy report

Above `func _report_economy() -> void:`:

```text
Where fuel and credits came from and went, per run.

THE LARGEST DEATH CAUSES ARE ECONOMIC. Runs end adrift with a dry tank or
holed because repairs were unaffordable, and neither is visible in a report
that only counts corpses. This is the sheet that says whether a galaxy is
payable at all.

FUEL EARNED PER JUMP is the number to watch when the galaxy is resized: a
bigger map costs more fuel to cross, and if income per system does not keep
pace the run simply runs out of road however large the tank starts.
```
