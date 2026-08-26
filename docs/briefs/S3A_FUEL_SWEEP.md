# S3a — sweep the fuel economy

*Written 2026-08-26, offline, against `main` at `dd998f8`. Line numbers move;
grep the quoted strings.*

**Two directions ruled 2026-08-26:** stations as the pump, and fuel from combat.
Plus the cost side. **This document does not implement any of them.** It makes
each one a dial, sweeps it, and reports. `ROADMAP.md` §7: *do not let a model
pick silently* — and equally, do not let one commit a balance change nobody
measured.

**Runs after S1 and S2.** A sweep against a broken strand counter measures the
counter.

---

## 0. ▲ Read this before designing the grid

**The sim will not buy fuel no matter how cheap you make it.**

`Policy.gd`:267-272 tops up only while `Run.fuel < tank * FUEL_TOPUP`, and
`FUEL_TOPUP := 0.5`. Half of 279 is **139**. A run that averages ~194 fuel in the
tank is never under that line, so it walks past the pump.

Which means the reported *"3 fuel from stations against 85 spent"* is **not a
supply figure. It is a demand figure.** `Market.REFUEL_UNITS` is 25 a purchase at
~12 credits; across 9.7 stations a run that is ~242 fuel available for ~116
credits, and the policy takes three.

**So `FUEL_TOPUP` must be swept BEFORE, or alongside, anything on the station
side.** Sweep refuel price against a policy that never refuels and every cell
returns the same number, and the conclusion — *stations do not help* — will be an
artifact of the harness. This is the same fault as 2a's first, unpaired vent
sweep, which measured the galaxy instead of the dial.

---

## 1. Method — the parts that are not negotiable

Taken from `Policy.gd`:36-60, which is the best worked example in the repo.

- **PAIR EVERY COMPARISON.** `-- sim seed=1000 runs=500`, so every cell faces the
  same 500 galaxies. `Rng.forced = N`, **never** `Rng.reseed`. Galaxy kind alone
  swings win rate 33–38 points, an order of magnitude more than any dial here.
  2a's unpaired sweep produced a confident, wrong answer.
- **500 runs a cell.** 300 was not enough to separate cells in 2a.
- **Report per kind, every cell.** The mean is not the target — see §5.
- **One dial at a time**, in the stages below. A full grid across three families
  is combinatorial and unreadable.
- **Ship nothing that did not measure.** *A change with no measured effect is a
  diff somebody has to read later for no reason.* If a cell wins by six runs in
  five hundred, that is noise; leave the constant alone and write down that it
  was swept.

### Add the dials the same way `ventcold=` was added

`HeadlessSim.gd`:85-96 parses `runs=`, `seed=`, `ventcold=`, `venthot=`. Extend
that list. Every constant below becomes a `const` that a CLI arg can override —
no other mechanism, no config file.

---

## 2. Stage A — demand. Sweep this first, alone.

| Dial | Now | Sweep |
| --- | --- | --- |
| `Policy.FUEL_TOPUP` | 0.5 | 0.5 · 0.65 · 0.8 · 0.95 |
| `Policy.FUEL_RESERVE` | 40 | 40 · 20 · 0 |

**This is the cheapest possible answer and it may be the whole answer.** If
raising `FUEL_TOPUP` makes the sim buy fuel and the strand rate falls, then
stations already work, the fuel economy is not broken, and Stages B and C are
answering a question that does not exist.

**It is also a harness change, not a game change.** `FUEL_TOPUP` describes how a
simulated pilot behaves, not how the game behaves. If Stage A alone fixes the
numbers, **nothing ships** — you have found a fifth instrument fault, and
`ROADMAP.md` §5's advice applies: *suspect the instrument before the design.*

Record which it was. It matters for what §7 becomes.

---

## 3. Stage B — stations as the pump

Only if Stage A leaves a real shortfall.

| Dial | Now | Sweep |
| --- | --- | --- |
| `Market.REFUEL_UNITS` | 25 | 25 · 40 · 60 |
| refuel price coefficient (`Market.gd`:230) | 12.0 | 12.0 · 8.0 · 5.0 |

Both scale by `service_index(n)`, so a deep station stays dearer than a rim one.
Keep that — it is the thing that makes a developed system worth reaching.

**Watch the credit line, not just the fuel line.** The economy block reports
`credits: +18 net per run`, which is thin. Cheap fuel that leaves nothing for
repairs is not a fix: `Policy`'s own comment says *hull loss is the largest death
cause and buying fuel instead of a hull is not competence.* Report credits spent
on fuel versus repair per run in every cell.

**What this direction buys, if it works:** stations become more load-bearing,
which suits their being the one telegraphed safe node under
`ENCOUNTER_REBUILD.md`. **What it risks:** stations are already a guaranteed
positive, and making them more so makes station-hopping the dominant route.

---

## 4. Stage C — fuel from combat

| Dial | Now | Sweep |
| --- | --- | --- |
| fuel per fight won | 0 | 0 · 2 · 4 · 6 |
| fuel per derelict stripped | 0 | 0 · 3 · 6 |
| chance a fight drops any at all | — | 1.0 · 0.5 |

**Structurally consistent with the reward-class ruling.**
`ENCOUNTER_REBUILD.md` §5 already gives fights modules and rarity; scavenging a
wreck for its tanks is the same idea and the same fiction.

**The risk, stated plainly.** Fights would then gate both your deck *and* your
mobility. The pacifist line stops being merely poorer and becomes unplayable,
which is a bigger design change than it looks — and the failing kinds average
**0.9 kills a run**, so a fuel source tied to combat gives the ships that need it
most almost nothing. **Check whether Stage C moves the tail at all.** If it lifts
the mean and leaves Barred Ring Spiral at zero, it has not worked.

Prefer the derelict half if both land: it pays for exploring rather than for
winning, and it does not punish a hurt ship for declining a fight.

---

## 5. Stage D — the cost curve

The option this document's author would look at hardest, and the only one that
targets the tail directly.

| Dial | Now | Sweep |
| --- | --- | --- |
| `RunState.FUEL_PER_DISC_RADIUS` | 13.0 | 13.0 · 11.0 · 9.0 |
| `RunState.FUEL_MAX_HOP` | 6 | 6 · 5 · 8 |
| `RunState.FUEL_PER_RING_STEP` | 150/7 | 150/7 · 170/7 |

**Read the comment above `FUEL_PER_DISC_RADIUS` first.** It went 17 → 13 as a
**unit conversion** when `hop_distance` stopped measuring in squashed space, not
as a balance change. Moving it again *is* a balance change, and the comment
should say so afterwards.

**The structural question underneath.** Jump cost is raw distance, so a sprawling
galaxy costs more to cross than a compact one — and the failing kinds are the
sprawling ones. A fourth dial worth testing, and it is a change in kind rather
than degree:

> **Price a jump against the galaxy's own scale rather than absolute distance.**
> Divide cost by the kind's `reach`, or by that galaxy's mean nearest-neighbour
> distance, so crossing a Giant Elliptical costs what crossing a Dwarf Spheroidal
> costs.

That would make the 38-point per-kind spread *structurally* smaller instead of
tuning around it. It also partly undoes the intent of `reach` being an authored
per-kind difference — see `GALAXY_SCALE.md` §4 — so it is a design ruling, not a
sweep cell. **Measure it as a cell; decide it as a ruling.**

---

## 6. What to report

Per cell, and per kind within each cell:

- win %, stranded %, **and the S1 split**: policy-gave-up vs genuinely stranded
  vs dry-tank vs nowhere-in-range
- avg jumps, avg kills, avg danger reached
- fuel: spent jumping, earned by source, **and mean fuel remaining at run end**
- credits: net, spent on fuel, spent on repair
- **worst kind's win % and jump count** — the gate

### The gate

`ROADMAP.md` §7: **gate on the tail, not the mean.** A cell that lifts the
average and leaves Barred Ring Spiral at 0% with 94 jumps has not worked. The
target is the 38-point spread closing, not the mean rising.

### Write it up

`docs/sim-baselines.md`, in the style of the 2a entry — including the cells that
did nothing. *Phases 3, 4 and 5 skipped this and that is why the regression went
unattributed.*

---

## 7. Expected outcome, recorded in advance

So the result can be checked against the prediction rather than rationalised
after it.

**Stage A alone is expected to move the numbers substantially**, because the
demand threshold is a far better explanation of "3 fuel a run" than any supply
constraint. If that is what happens, S3 was never a design problem, Stages B–D
are unnecessary, and the correct output of tonight is a `sim-baselines.md` entry
and **no game code changed at all**.

If Stage A does little, the shortfall is real and B–D are the menu.

**Being wrong here is a fine outcome and should be written down either way.**
