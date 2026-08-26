# Sim baselines

Every numbered phase of `ROADMAP.md` records its `-- sim runs=500` here, before
and after. The point is **attribution** — knowing which change moved a number —
not holding a line. Per ROADMAP §4 the win rate is *expected* to rise, and per
the ascension/difficulty-ladder direction a generous level 1 is the design
rather than a fault.

Run it the same way every time or the numbers are not comparable:

```bash
godot --headless --path tkg -- sim runs=500
```

---

## Phase 0 — baseline, 2026-08-25

Taken at `53aa8ea`, immediately after per-kind reporting landed and immediately
before `HEAT_REWORK`. SaveGame VERSION 14, PROTOCOL 8.

```
runs 500 · wins 177 (35%) · deaths 274 · errors 0
avg jumps 38.0 · avg kills 7.4 · avg danger reached 7.87
death causes: Hull integrity lost 196 · Adrift, tank dry 66 · neutron star 6 · reactor 6
stranded, ended by check_stranded() 100 (20.0%) · of those, blocked by fuel 66
heat: avg signature on arrival 0.04 · arrived hot 981 of 19488 (5.0%)
post-fight signature 0.14 · left a fight hot 750 of 3924 (19.1%)
hellbender: met 93 · engaged 63 · killed 21 · escaped 40 · derelicts eaten 2.24/run
ambushes 70 (0.14 per run) · runs jumped at least once 36 (7.2%)
```

### Three things this says that the design briefs did not know

**1. The heat targets in `HEAT_REWORK.md` §3 are stale by an order of
magnitude.** That brief targets *"roughly the old 0.32 average arrival
signature"*, a figure recorded when half-rate transit cooling was chosen over
full. Half rate today measures **0.04**. Something moved underneath it, and the
0.32 target cannot be aimed at because the game is nowhere near it.

**Ambush is effectively not in the game.** `SIGNATURE_FLOOR` is 0.25 and mean
arrival signature is 0.04, so almost nothing finds you: 0.14 ambushes per run,
and **92.8% of runs are never jumped at all.** `ENCOUNTER_REBUILD.md` §6 wants
signature to become the map's *only* involuntary risk — it is currently the
map's only involuntary risk and it fires almost never.

**2. The galaxy kind is a 33-point difficulty setting nobody chose.**

| kind | runs | win% | jumps | kills | systems |
| --- | --- | --- | --- | --- | --- |
| Flattened Elliptical | 43 | 49% | 24.7 | 7.2 | 141.4 |
| Grand-Design Spiral | 30 | 47% | 42.9 | 7.7 | 158.3 |
| Collisional Ring | 30 | 47% | 17.5 | 4.3 | 166.4 |
| Lenticular | 25 | 44% | 30.6 | 7.4 | 131.9 |
| Giant Elliptical | 31 | 42% | 26.4 | 8.6 | 173.3 |
| Barred Lenticular | 32 | 38% | 23.7 | 6.5 | 132.1 |
| Barred Ring Spiral | 38 | 37% | 33.0 | 4.5 | 154.3 |
| Interacting Pair | 25 | 36% | 25.5 | 6.7 | 158.1 |
| Irregular | 28 | 36% | 36.8 | 8.3 | 164.6 |
| Starburst Spiral | 37 | 35% | 27.8 | 6.3 | 157.4 |
| Barred Spiral | 29 | 31% | 31.8 | 5.9 | 155.6 |
| Round Elliptical | 34 | 29% | 59.8 | 12.2 | 187.9 |
| Multi-Arm Spiral | 39 | 28% | 39.8 | 7.1 | 160.3 |
| Flocculent Spiral | 40 | 25% | 59.4 | 7.7 | 157.9 |
| Dwarf Spheroidal | 39 | 15% | 75.3 | 9.6 | 179.2 |

Cells are 25–43 runs, so individual rows are soft. The **spread** is not: 49%
down to 15%, and it tracks a legible mechanism — more systems means more jumps
means more chances to die and more fuel spent. Jumps run **17.5 to 75.3, a
factor of 4.3**, off nothing but which galaxy rolled.

`GALAXY_SCALE.md` §4 rules that different galaxies playing differently is
*wanted* and should be promoted from accident to authored. This table is the
argument for that ruling, and it is stronger than the brief assumed.

**3. It is also a warning about `LAYERS := 15`.** The brief targets 25–35 actual
jumps. The mean is already **38**, and a Dwarf Spheroidal already runs **75**.
Doubling the systems makes the long galaxies far longer, not the short ones
longer. Whatever `density`/`reach` values get authored in phase 4 have to pull
the tail *in* as well as pushing the middle out.

### And one framing correction

`GALAXY_SCALE.md` §0 opens *"A run is eight jumps long"* and compares that to
FTL's 40–60. Eight is the **shortest forced path to the core**; a competent
player actually takes **38**. The real problem is that the fast dive is
*available and dominant if you want it*, which is worth fixing — but the game is
not eight jumps long, and the FTL comparison is between a minimum and an actual.
