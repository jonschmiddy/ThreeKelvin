# Fix the instrument before ruling on fuel

*Written 2026-08-26, offline, against `main` at `dd998f8`. Line numbers will
move; grep the quoted strings.*

**Do this before `ROADMAP.md` §7.** §7 asks for a design ruling on where fuel
income comes from. The number that ruling rests on — 38.8% stranded, 106 of them
blocked by fuel — is measured over the wrong set. Rule after it is measured
correctly, not before.

This is `ROADMAP.md` §5's own lesson: *four separate faults found during that
work were in the simulator, not the game. Suspect the instrument before the
design.* This looks like a fifth.

---

## In short

**The finding.** The player may jump to anything inside a radius; the simulator
may only follow charted `links`. `Policy.choose_jump` returning -1 is counted as
a strand, so "38.8% stranded" means *the policy ran out of charted options*, not
*the run ended*. A run averages 279 fuel in and 85 spent — 70% of the tank
unused.

**The work.** Three harness changes, **no game code**. If the game needs
changing, that is §7's ruling and it should be made against corrected numbers.

- **F1** — count a strand only when `has_legal_jump()` is false. Keep
  `policy_gave_up` alongside it and print both: **the gap between them is the
  size of the blind spot**, and that gap is the number saying whether any of
  this mattered.
- **F2** — fix `stranded_no_fuel` to test the reachable set and require *all*
  options unaffordable. This splits out a failure mode that currently has no
  name: **nowhere to go at any price**, which is a map problem rather than an
  economy one. If it is non-zero, §7 is aimed at the wrong thing entirely.
- **F3** — give the policy `in_range_of()`, the set the chart actually offers.
  **Expect behaviour to change, not just measurement.** A policy confined to
  charted links routes worse than one that can see everything in range, and the
  failing kinds are exactly the ones with enormous jump counts — which is what a
  badly-routed ship looks like. If the 38-point per-kind spread collapses,
  re-baseline before tuning anything. Watch the cost: `in_range_of` is a pass
  over every system and is not cached.

**Then decide.** §4's table maps each possible result onto what §7 turns out to
be about.

**Also in here:** §5 is a real, unrelated bug in ring placement — separate work,
own sim run, do not bundle it. §6 records two theories already tested and
rejected, so nobody re-derives them.

---

## 1. The arithmetic does not close

A run starts with `FUEL_PER_RING_STEP * (LAYERS - 2)` = **279 fuel**
(`RunState.gd`:314). The sim reports **85 spent jumping**.

So the average run ends with roughly **194 fuel unspent — 70% of the tank** —
while 38.8% of runs supposedly end adrift. Even the worst case in the per-kind
table, Barred Ring Spiral at 94.6 jumps, is 94.6 × 1.80 ≈ 170, comfortably
inside 279.

**Those two facts cannot both be about fuel scarcity.** One of them is
mismeasured.

---

## 2. The simulator plays a different game from the player

### The player routes on a radius. The policy routes on links.

`RunState.reachable_from()`:1921 — a hop is legal if either end's
6-nearest-neighbour radius encloses the other. `can_jump_to()` is
`reachable() and fuel >= fuel_cost_to()`. `has_legal_jump()` scans **the whole
map**. Nothing in that path consults `node.links`.

`Policy.choose_jump()`:345-351 builds its option set from **`node.links`**:

```gdscript
for idx in node.links:
    if Run.can_jump_to(Run.map[idx]):
        options.append(idx)
if options.is_empty():
    return -1
```

`links` is the generated graph — ring links plus doors. The reachable set is a
distance radius. **They are different sets, and the policy uses the narrower
one.** Every jump the chart would offer that is not a charted link is invisible
to the simulator.

So `pick < 0` does not mean *stranded*. It means *no charted link was usable* —
a much weaker condition, and one that gets weaker still every time door density
changes.

### And the sim counts that as stranding

`HeadlessSim.gd`:276-284:

```gdscript
var pick := policy.choose_jump(node)
if pick < 0:
    Run.check_stranded()
    stranded += 1
```

`check_stranded()` is called and **its answer is not used.** The counter
increments on the policy giving up, not on the game declaring the run over.

### The fuel counter has a second, independent fault

Same block:

```gdscript
for idx in node.links:
    if Run.fuel < Run.fuel_cost_to(Run.map[idx]):
        stranded_no_fuel += 1
        break
```

It breaks on the **first** unaffordable link, so it reports *at least one link
was unaffordable* — not *nothing was affordable*. Over the wrong set, again.

"Blocked by fuel: 106" therefore means neither "ran out of fuel" nor "had no
affordable jump".

### The fallback walks the same narrow graph

`choose_jump`:396-403, looking for a neighbour that can itself descend, reads
`Run.map[idx].links` — links again. On top of the door-walk fix that landed in
phase 5 (a genuine improvement), the walk is still routed over a graph the
player is not confined to.

---

## 3. The fix

Three changes, all in the harness. **No game code changes here** — if the game
needs changing, that is §7's ruling and it should be made against corrected
numbers.

### F1 — Count a strand only when the game says so

```gdscript
var pick := policy.choose_jump(node)
if pick < 0:
    var really := not Run.has_legal_jump()
    policy_gave_up += 1
    if really:
        stranded += 1
        if <no affordable option among in_range_of(node)>:
            stranded_no_fuel += 1
    break
```

Keep **both** counters and print both. The gap between `policy_gave_up` and
`stranded` is the size of the instrument's blind spot, and it is the number that
says whether any of this mattered.

### F2 — Fix `stranded_no_fuel` to mean what it says

Test the same set `can_jump_to` uses, and require **all** options unaffordable:

```gdscript
var any_reachable := false
var any_affordable := false
for n in Run.in_range_of(node):
    any_reachable = true
    if Run.fuel >= Run.fuel_cost_to(n):
        any_affordable = true
        break
```

Then `stranded_no_fuel` is `any_reachable and not any_affordable` — a dry tank —
and `any_reachable == false` is a genuinely different failure worth its own
counter: **nowhere to go, at any price.** If that one is non-zero it is a map
problem, not an economy problem, and §7 would be aimed at the wrong thing
entirely.

### F3 — Give the policy the set the player has

`RunState.in_range_of(here)`:1930 already returns exactly what the chart offers.
Swap it in at `choose_jump`:347 and at the fallback's door search:398.

**Expect this to change behaviour, not just measurement.** A wider option set
means better routing, likely fewer jumps, and possibly a large move in the
per-kind spread — the failing kinds are the ones with the highest jump counts,
which is what a badly-routed ship looks like.

**Watch the cost.** `in_range_of` is a pass over every system, called per jump,
at ~287 systems × ~47 jumps × 500 runs. `_range_cache` covers the map half of
`range_from` but `in_range_of` itself is not cached. If the sim slows
unacceptably, cache per node per run rather than reverting.

---

## 4. Re-run, then decide

```bash
godot --headless --path tkg -- sim runs=500
```

Paired against phase 0's baseline — `Rng.forced = N`, **not** `Rng.reseed`, per
`ROADMAP.md` §7.

Four numbers decide what §7 is actually about:

| If | Then |
| --- | --- |
| Runs end with ~190 fuel and legal jumps available | The strand figure was an artifact. **Fuel income is not the problem.** Look at the policy and the map. |
| Runs end genuinely dry | §7 stands. Make the income ruling, on solid ground. |
| `any_reachable == false` is common | **A map problem, not an economy one.** Systems out of range of everything. |
| The per-kind spread collapses after F3 | The 38-point spread was substantially the instrument. Re-baseline before tuning anything. |

**Write it up in `docs/sim-baselines.md` either way.** Phases 3–5 skipped this
and `ROADMAP.md` §4 names that as why the regression went unattributed.

---

## 5. Unrelated real bug, found while checking the above

**`ring_count()` and `galaxy_pos()` disagree about where a ring is.**

- `ring_count()`:250 sizes a ring's population from `ring_radius(layer)` — the
  **un-holed** radius.
- `galaxy_pos()`:697-699 then places that ring at `hole + rn * (1.0 - hole)`.

On a Collisional Ring (`ring = 0.52`) the innermost ring is counted for radius
**0.110** and drawn at **0.573** — a circle 5.2x larger carrying the population
of the small one. Measured spacing along that ring is 0.257 disc radii against
0.16 on the rings outside it, so the field gets *sparser* toward the middle,
which is the opposite of what `ring_count`'s weighting comment says it is for.

The same one-quantity-two-places pattern as everything else in
`DOC_RECONCILIATION.md`. Fix: apply the hole inside `ring_radius()` so both
callers see the same radius, or pass the placed radius into `ring_count()`.

**This does not explain the tail** — see §6 — and should not be bundled with the
instrument work. It changes node counts on two galaxy kinds, so it wants its own
sim run.

---

## 6. Two theories tested and rejected — do not spend a session on these

Recorded so they are not re-derived.

**Ring-hole galaxies are not structurally expensive to cross.** The two worst
kinds are the only two with `ring > 0`, which looks damning. Minimum coreward
fuel bill, computed over the real geometry:

| kind | ring | systems | min coreward fuel |
| --- | --- | --- | --- |
| Dwarf Spheroidal | 0.00 | 156 | **29** |
| Collisional Ring | 0.52 | 254 | 19 |
| Lenticular | 0.00 | 243 | 19 |
| Grand-Design Spiral | 0.00 | 286 | 18 |
| **Barred Ring Spiral** | 0.34 | 269 | **18** |
| Round Elliptical | 0.00 | 338 | 17 |

Barred Ring Spiral is 0% win and costs exactly what Grand-Design costs. Dwarf
Spheroidal is the dearest to cross and does not fail. Against a 279 tank, none
of these is close to binding.

**Arm clustering cannot trap a ship.** `galaxy_pos`:730 clamps the arm pull to
`±astep * 0.6`, with a comment recording that an uncapped pull is what once made
one-fuel jumps cross the whole galaxy. Angular positions stay within 0.6 of a
ring step of even spacing, so no kind can open a void wide enough to strand
anyone.
