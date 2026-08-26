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

---

## Phase 2 — HEAT_REWORK, 2026-08-25

`HEAT_REWORK.md` ruled two changes. **One landed. One was tried and put back**,
which is what that brief asked for when it said *"Re-run the measurement; do not
assume it lands right."*

### What landed: dissipation amplifies venting (§2)

The end-of-turn shed in combat is deleted; a vent card now sheds
`vent + dissipation()`.

| | phase 0 | after §2 |
| --- | --- | --- |
| win rate | 35% | **30%** |
| post-fight signature | 0.14 | **0.31** |
| left a fight hot | 19.1% | **37.7%** |
| overheat deaths | 6 | **47** |
| ambushes per run | 0.14 | **0.21** |
| runs ever jumped | 7.2% | **14.8%** |

It does what it was for. Heat accumulates instead of being refunded, fights end
near capacity, and the run-hot archetype that `heat_scale`,
`damage_equals_heat` and `brace_from_heat` have been waiting for now has room to
exist. Ambush roughly doubled purely as a side effect of hotter fights.

**Overheat deaths went 6 → 47.** §7 anticipates this: *"If burn spikes, the vent
multiplier is not carrying enough and the answer is more vent cards in the pool,
not restoring the drip."* Part of it is that the sim's policy has not been
retuned — `Policy.gd`:86 is still playing the old game.

### What was reverted: full-rate transit cooling (§3)

Three 500-run passes with the combat change held constant:

| transit | arrival sig | arrived hot | ambush/run | win |
| --- | --- | --- | --- | --- |
| full rate (§3 as ruled) | 0.04 | 5.5% | 0.21 | 30% |
| **half rate (kept)** | **0.07** | **9.4%** | **0.24** | 29% |
| *(phase 0, for reference)* | 0.04 | 5.0% | 0.14 | 35% |

Half rate is better on **every axis the change was for**, and the one point of
win rate is inside the noise of 500 runs.

### The finding underneath both, which is the useful part

**The transit rate is not the lever, and the 0.32 target is unreachable by
tuning it.**

Fights now end at 0.31 signature — more than double phase 0 — and arrival is
still **0.07** against a `SIGNATURE_FLOOR` of **0.25**. Cooling is charged *per
jump* and there are roughly four jumps per fight, so whatever a fight builds is
spent long before the next one. Halving the rate cannot fix that; neither can
doubling it.

If `ENCOUNTER_REBUILD.md` §6 wants signature to be the map's involuntary risk
dial, the dials that would actually move it are:

- the **per-jump floor** of 1, which sheds even on a ship with no dissipation
- the **number of jumps between fights** — a galaxy question, not a heat one
- **`SIGNATURE_FLOOR` itself**, currently 0.25 against a curve that peaks at 0.31

### H amplifies the galaxy spread

The kind spread widened 33 → 38 points, and it is the long galaxies that
collapsed: Round Elliptical 29% → 10%, Flocculent Spiral 25% → 7%. More jumps
means more fights, and fights now cost more heat. Worth knowing before phase 3
doubles the system count.

### §7's fourth check: the two policies still diverge, but barely on heat

| 500 runs | cold (default) | hot (`-- sim hot`) |
| --- | --- | --- |
| win rate | 29% | **26%** |
| post-fight signature | 0.31 | 0.32 |
| arrived hot | 9.4% | 9.4% |
| overheat deaths | 59 | 63 |

Three points of win rate apart, so they are not identical — but their **heat
profiles are now the same to two decimal places**, which is precisely what §7
says to watch for: *"if both policies now behave the same, the threshold needs
retuning before any other number here is trustworthy."*

`Policy.gd`:86 vents at `heat_cap * 1.15` when hot and `* 0.7` when cold. With
the free shed gone, heat climbs fast enough that both thresholds are crossed in
the same turns, so the "hot" model is not actually running hotter — it is just
dying slightly more. **Retuning that threshold is the first thing to do before
trusting any further heat number**, and it is deliberately not done in the same
commit as the change it would be measuring.

---

## Phase 2a — the vent thresholds, swept and left alone, 2026-08-25

`HEAT_REWORK.md` §7 asks whether the sim's two policies still diverge after the
end-of-turn shed was deleted. They did not, so the thresholds were swept. **The
answer is that this dial does nothing, and the values are unchanged.**

### The method mattered more than the result

An unpaired sweep at 300 runs a cell looked decisive — both old values landed
worst in their own column, cold 0.70 at 22% against 0.50 at 28%. **It was
measuring the galaxy, not the threshold.** Every run rolls a different galaxy
and the kind alone swings win rate 33–38 points (phase 0), which is an order of
magnitude larger than anything a vent rule does. A 500-run confirm reversed the
ordering.

Re-run **paired** — `seed=1000`, so both configs face the same 500 galaxies:

| config | win | cooked | arr.sig | fight.sig | arrived hot |
| --- | --- | --- | --- | --- | --- |
| cold 0.50 | 27% (135) | 52 | 0.07 | 0.31 | 8.4% |
| cold 0.70 | 26% (129) | 53 | 0.07 | 0.32 | 8.6% |
| hot 1.00 | 26% (128) | 65 | 0.07 | 0.34 | 9.3% |
| hot 1.15 | 26% (128) | 62 | 0.07 | 0.34 | 9.2% |

Six wins in five hundred between the cold pair, none between the hot pair, every
heat number the same.

**Rule for every future sweep in this file: pair it with `seed=`.** Unpaired
comparisons of anything smaller than the galaxy effect are unreadable, and that
now includes most balance dials.

### Why the dial is inert — and it is not a heat problem

**The hot policy is modelling Solari, on a Korvan ship.**

`design-doc.md` has them as mirrored heat philosophies: *"Korvan/Solari are
mirrored heat philosophies (manage it vs. surf it)"*, with Solari as
*"weaponized heat: plasma damage scales with current heat, deliberate
overheating for payoff, offensive venting"* — and **Korvan as the starter kit**.

Korvan is also the only entry in `ACTIVE_MANUFACTURERS`. So the sim is asking
the manufacturer whose identity is *managing* heat to *surf* it, with that
manufacturer's own loot. It loses because it should.

The three cards that want heat high are all Solari modules — Plasma Lance
(`heat_scale`), Thermal Purge (`damage_equals_heat`), Heat Shroud
(`brace_from_heat`). **Solari is 7 modules of a targeted 40** and does not drop.

So §7's divergence check is not blocked on heat tuning or on writing generic
run-hot cards. It is blocked on **Solari existing and being switched on**, which
is blocker B4 and already tracked. Until then the hot policy has no ship to
describe, and this dial is measuring the wrong manufacturer.

**What `HEAT_REWORK` §2 did buy Solari**, when it arrives: venting is now a
deliberate act that carries the ship's whole radiator, which is exactly what
*"offensive venting"* needs — Thermal Purge is `damage_equals_heat` plus
`vent_all`, and it now lands in a game where heat actually accumulates to spend.

