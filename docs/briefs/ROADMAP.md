# ROADMAP — read this first

*Originally written 2026-08-25 as a routing document. **Updated 2026-08-26**
against `main` at `dd998f8`, after an offline analysis session. Phases 0–5 done,
phase 5 parked. **A new precondition (S-phases) now sits in front of §7 and
phase 6** — see §1.*

This is the index. Every other file in this bundle is linked from here and
nothing should be read without coming through this first.

---

## 0. The bundle

**None of these are in the repo.** Git has no record of them. **Commit them to
`docs/` in the first commit of the session before anything else** — they have
been driving the work for two days and exist on one desktop.

| File | What it is | Status |
| --- | --- | --- |
| `ROADMAP.md` | this index and the phase tracker | live |
| `SIM_INSTRUMENT_FIX.md` | **tonight's first job.** The strand counter measures the wrong set | ⬜ **do first** |
| `S3A_FUEL_SWEEP.md` | the fuel sweep spec — dials, stages, the gate | ⬜ after S2 |
| `ENCOUNTER_REBUILD.md` | options replace node types; the phase 6–8 design | ⬜ next |
| `ENCOUNTER_FLOW.md` | **what the player sees** — arrival to departure, four UX rulings | ⬜ phase 8 |
| `ENCOUNTER_AUTHORING.md` | **how to write more** — pipeline, rules, audit spec | reference |
| `batch-02-draft.md` | first six authored options, plus six ported events | draft |
| `batch-03.md` | twenty more, aimed at the coverage gaps | draft |
| `encounter-prototype.html` | playable feel-test: 10 systems, 29 options | tool |
| `ENCOUNTER_GENERATION.md` | how to fill the option pool; gating, archetypes, the region distribution | reference |
| `GALAXY_SCALE.md` | map scale, declared galaxy shape, the chart primer | §1–§4 ✅ · §3 parked · §5 ⬜ |
| `HEAT_REWORK.md` | dissipation amplifies venting | ✅ landed (§3 reverted) |
| `LIVE_CARD_NUMBERS.md` | live card faces and the targeting line | ⬜ unblocked |

Two earlier briefs are fully applied and are not in this bundle:
`VERSION_GATE_FIXES.md` and `DOC_RECONCILIATION.md`.

---

## 1. STATE OF THE WORLD

**Repo:** `main` at `dd998f8`, in sync. Clean. `SaveGame VERSION 14`,
`PROTOCOL 8`, `validate.sh` passing.

**⚠ `VERSION` IS ALREADY 14.** `be37b3e` stamped it during the attributes work —
sensors added a `sensed` key to every map node. **Phase 6 bumps 14 → 15.** If
`version_guard.py` fires outside phase 6, investigate rather than bumping.

**Map constants** (`MapGen.gd`):

```
LAYERS := 15          RING_SPACING := 0.1157    SQUASH_REF := 0.62
DOOR_SHARE := 1.00    MIN_DOORS := 2            RING_MIN/MAX := 5 / 60
```

`DOOR_SHARE := 1.00` means **phase 5 is parked, not done** — §5.

**Instruments.** Use them; *"it feels wrong" is not a number.*

| Command | Answers |
| --- | --- |
| `-- sim runs=500` | the balance gate; per-kind table and economy block |
| `-- maptest` | is every ring reachable, what is the forced path (120 galaxies) |
| `-- chartbench` | starchart frame cost. **Needs a window** |
| `-- zoomshot` | chart at a zoom ladder + radial density. **Needs a window** |

**`--headless` never emits `frame_post_draw`.** A harness that draws must run
windowed (`godot --path tkg -- <name>`) or it hangs looking like a bug.

---

## 2. TONIGHT'S QUEUE

In order. Do not skip ahead — each one changes what the next is about.

| | Job | Read | Why it is here |
| --- | --- | --- | --- |
| **S0** | Commit these docs to `docs/`. Then the recovery check | `ENCOUNTER_GENERATION.md` §0 | Five minutes, and it may save re-deriving 100 event seeds |
| **S1** | **Fix the simulator's strand accounting** | `SIM_INSTRUMENT_FIX.md` §3 | §7's ruling rests on a number measured over the wrong set |
| **S2** | Re-run `-- sim runs=500`, paired. Write up in `sim-baselines.md` | `SIM_INSTRUMENT_FIX.md` §4 | Four outcomes, four different meanings for §7 |
| **S3** | **The fuel ruling — if S2 still says it is needed** | §7 below | **Human decision. Do not let a model pick silently** |
| **S3a** | **Sweep it.** Demand first, then stations, combat, cost curve | `S3A_FUEL_SWEEP.md` | Two directions ruled; measure before shipping either |
| 6 | Option model, table, roller | `ENCOUNTER_REBUILD.md` §4–§5, §5a | bumps `SaveGame` **14 → 15** |
| 7 | Option policy in the sim | `ENCOUNTER_REBUILD.md` §8 | not optional — see §4 |
| 8 | Collapse `NodeType`, ambush becomes an interrupt | `ENCOUNTER_REBUILD.md` §6–§7 · **`ENCOUNTER_FLOW.md`** | the flow doc is what phase 8 builds |

**S1 before S3 is the whole point of this update.** The instrument may be
inventing the problem S3 exists to solve.

### The S1 headline

A run starts with **279 fuel** and spends **85**. Seventy percent of the tank
goes unused — yet 38.8% of runs are reported stranded. Both cannot be true.

`Policy.choose_jump` builds its options from **`node.links`**; the game allows
any jump inside a **radius** (`reachable_from`, `has_legal_jump`). The policy
returning -1 is counted as a strand. It is not one — it means *no charted link
was usable*.

Full argument, the three fixes, and what each possible result means:
**`SIM_INSTRUMENT_FIX.md`**.

---

## 3. THE REGRESSION — why S1 exists

Both columns `-- sim runs=500`. Left is phase 0 banked at `53aa8ea`; right is
`dd998f8`.

| | Baseline | Now | |
| --- | --- | --- | --- |
| wins | 177 (**35%**) | 94 (**19%**) | ▼ halved |
| stranded | 100 (20.0%) | 194 (**38.8%**) | ▼ doubled |
| avg jumps | 38.0 | 47.3 | ▲ longer |
| avg kills | 7.4 | 5.3 | ▼ fewer fights |
| avg danger reached | 7.87 | 5.70 | ▼ shallower |
| per-kind spread | 33 pts (49→15) | **38 pts (38→0)** | ▼ wider |

**What DID work: heat.** Post-fight signature 0.14 → **0.32**, "left a fight
hot" 19.1% → **34.9%**, ambushes 0.14 → **0.21** per run. Phase 2 did exactly
what `HEAT_REWORK.md` §2 wanted. **Do not re-open it.**

The losing kinds share one signature — huge jump counts, almost no kills:

| kind | win% | jumps | kills |
| --- | --- | --- | --- |
| Irregular | 38% | 24.5 | 9.8 |
| Barred Spiral | 13% | 64.9 | 3.1 |
| Collisional Ring | 3% | 87.2 | 1.6 |
| Barred Ring Spiral | **0%** | 94.6 | **0.9** |

Ninety-four jumps and 0.9 kills is a ship wandering a map it cannot route on.
**That is what a policy confined to charted links looks like**, which is why S1
comes before any economy change.

**Two theories already tested and rejected** — ring-hole geometry and arm
clustering. Numbers in `SIM_INSTRUMENT_FIX.md` §6. Do not re-derive them.

---

## 4. Phases

| # | Phase | Status |
| --- | --- | --- |
| 0 | Bank the baseline | ✅ `53aa8ea`, in `docs/sim-baselines.md` |
| 1 | Per-kind sim reporting | ✅ `53aa8ea` |
| 2 | **H** — dissipation amplifies venting | ✅ landed. Transit cooling **reverted** — §6 |
| 2a | Vent thresholds swept | ✅ left unchanged, and it was the wrong question |
| 3 | **G** — `RING_SPACING` split, `LAYERS := 15` | ✅ + four constants that assumed nine |
| 4 | **G** — `density`/`reach`, clamp (D1) | ✅ fingerprint extended. **Carried a stranding regression** |
| 5 | **G** — sparse coreward links | ⏸ **PARKED** at `DOOR_SHARE 1.00` — §5 |
| **S0–S3** | **docs, instrument, re-measure, fuel ruling** | ⬜ **tonight** |
| 6 | **E** — option model, table, roller | ⬜ bumps `SaveGame` **14 → 15** |
| 7 | **E** — option policy in the sim | ⬜ not optional |
| 8 | **E** — collapse `NodeType`, ambush interrupt | ⬜ **`ENCOUNTER_FLOW.md` is the spec** |
| 9 | Tune | ⬜ |
| 10 | **G §5** — chart primer | ⬜ after phase 8 |
| 11 | **L** — live card faces | ⬜ |
| 12 | **L** — targeting line | ⬜ unblocked — **D2** ruled |

**Phase 7 is not optional.** Without an option policy the sim takes everything,
overstates income, and never exercises the exclusivity that is the whole point of
phase 6.

**Phases 3, 4 and 5 were never written up in `sim-baselines.md`** — it records 0,
2 and 2a only. That gap is why the regression went unattributed for as long as it
did. **Do not repeat it for S2.**

### Ordering constraints that still hold

- **G §5, the chart primer, comes after phase 8.** Phase 8 collapses `NodeType`
  and deletes four of the chart's six icon entries; a primer written first
  documents a legend about to change.
- **▲ E and L both make large edits to `SectorScreen.gd`** — one 1,221-line file
  that is both the arrival screen and the combat screen. **Sequence them. Do not
  run phases 6–8 and 11–12 on parallel branches.**

---

## 5. Why phase 5 is parked

Sparse coreward doors were built, measured, and backed out to `DOOR_SHARE 1.00`.

The mechanism works — reachability moved from *every system* to *every ring*,
which is what makes the lateral web load-bearing, and `-- maptest` proves nothing
is orphaned. **It is parked for what it does to the numbers, not because it is
wrong.**

Thinning doors makes the player walk further to find a way in. With the strand
figure as it stands, walking further is what appears to kill them. **Phase 5 must
not be un-parked until S2 is in** — and S1 may change the picture entirely, since
door-thinning hurts a link-routed policy far more than a radius-routed one.

`Policy.choose_jump` was taught to walk toward a door rather than random-walk the
ring — a genuine fix, still in. Un-parking will want real pathfinding there.

---

## 6. What the briefs got wrong

Goals right; three of four had a mechanism that did not survive measurement.

- **`HEAT_REWORK.md` §3's target is stale by an order of magnitude.** It aims at
  *"roughly the old 0.32 average arrival signature"*; measured was **0.04**.
- **Full-rate transit cooling was reverted.** It made the heat curve worse.
  Dissipation-amplifies-venting is the half that landed.
- **The vent thresholds are inert** — swept in 2a. Galaxy variance swamps the dial.
- **`GALAXY_SCALE.md` §0's "a run is eight jumps long" is a minimum, not an
  actual.** A competent player takes 38–47. The FTL comparison there is between a
  minimum and an actual; ignore it.
- **`GALAXY_SCALE.md` §3's "keep the reachability loop exactly as it is"**
  contradicts its own section — that loop is what made door-thinning impossible.
  It was changed.
- **And now: `SIM_INSTRUMENT_FIX.md` §6 rejects two more theories** that looked
  obvious from the per-kind table.

### The heat framing, corrected

**Korvan run cold. That is the plan.** All three heat-scaling cards belong to
Solari, who are 7/40 authored and not in `ACTIVE_MANUFACTURERS`. Any reasoning
that assumes a run-hot option exists is reasoning about a manufacturer that does
not.

---

## 7. The fuel ruling — S3, *if S2 still says it is needed*

**Conditional on S2.** If runs turn out to end with ~190 fuel and legal jumps
available, this section is answering a question that does not exist and phase 6
starts instead.

If it survives S2, the shape:

1. **Reproduce.** `-- sim runs=500`, read `economy per run`.
2. **Directions ruled 2026-08-26: stations as the pump, and fuel from combat.**
   Plus the cost curve as a third line of enquiry. **None of them ship
   unmeasured** — `S3A_FUEL_SWEEP.md` turns each into a dial and sweeps it.

   ▲ **Sweep demand before supply.** `Policy.FUEL_TOPUP := 0.5` means the sim
   only buys fuel below 139 of a 279 tank, and it averages ~194 — so it walks
   past the pump. **"3 fuel from stations" is a demand figure, not a supply
   one**, and sweeping station prices against a policy that never refuels
   measures nothing. Stage A of that document may dissolve S3 entirely, in which
   case the correct output is a `sim-baselines.md` entry and no game code
   changed.
3. **Gate on the tail, not the mean.** Barred Ring Spiral at 0% with 94.6 jumps
   is the problem; a fix that lifts the mean and leaves the tail at zero has not
   worked.
4. **Write it up in `docs/sim-baselines.md`.**

### Method rules, learned the hard way

- **Pair your comparisons.** `Rng.forced = N`, **not** `Rng.reseed` —
  `start_new_run` rolls its own master seed, so reseeding before it changes
  nothing. Galaxy variance is 33–38 points and swamps most dials.
- **Build the measuring tool first.** Every real finding this week came from an
  instrument, and several came from finding the instrument was wrong.
- **A green test you have not watched fail is worth nothing.**
- **Read the comment above the line before changing it.** Several constants
  document, in place, why the obvious change was already tried and backed out.

---

## 8. Open decisions

**D1 — Galaxy anisotropy. ANSWERED: measure un-squashed.** Chosen against the
brief's recommendation. Landed in phase 4. `hop_distance` divides y by squash, so
every distance grew ~1/0.62; `FUEL_PER_DISC_RADIUS` went 17 → 13 as a **unit
conversion, not a balance change.**

**D2 — Does hand reorder survive a targeting line? ANSWERED: no, drop it.**
Ruled 2026-08-26. A hand that rearranges itself under you is disorienting. It is
also the cheapest of the three options and turns phase 12's hardest problem into
a **net deletion** — `HandView` loses `reordered`, `_can_drop_data`,
`_drop_data`, `reorder_onto`, `_preview_slot` and `_drag_card`, and stops being a
drop target. Releasing over the hand becomes *cancel*, which hands the
hand-rolled gesture its cancel path nearly for free. **Phase 12 is unblocked.**
See `LIVE_CARD_NUMBERS.md` §3a.

**S3 — where fuel income comes from.** See §7. Conditional on S2. **This is now
the only open decision in the roadmap.**

---

## 9. Standing constraints

- **Ship Korvan-only, to a small group of friends, months out.** Core systems
  before more manufacturers. Korvan is not finished.
- **Win rate is deliberately de-prioritised** in favour of systems work.
  Ascension-style difficulty levels are planned, so a generous level 1 is the
  design. *That does not extend to the 0% tail in §3, which is a broken loop.*
- **No PixelLab generation without explicit approval.** 39 modules and 73 cards
  undrawn, 8 sprites awaiting a verdict.
- **The word is "manufacturer".** Never house, maker, brand, or marque.
  `validate.sh` enforces it on scripts and docs.

---

## 10. Known drift to fix in passing

Not phases; fix whoever is next in the file.

- **`design-doc.md`:116-118** describes affixes as modifying card behaviour, with
  three examples now impossible by design. `AffixData.gd` documents the reversal.
  Line 92's "generates 0 heat" chase-item claim is stale for the same reason.
  *Nothing automated watches semantic claims — the vocabulary guard watches
  words, `version_guard` watches shapes.*
- **`ring_count()` and `galaxy_pos()` disagree about where a ring is.** Population
  sized from the un-holed radius, placed at the holed one. On a Collisional Ring
  the innermost ring is counted for radius 0.110 and drawn at 0.573.
  `SIM_INSTRUMENT_FIX.md` §5. **Own sim run; do not bundle with S1.**
- **`GalaxyGen.gd` header** claims galaxy shape cannot move a jump or a fuel cost.
  It can, and does. Also says fourteen kinds; there are fifteen.
- **`validate.sh`** prints a stray `grep: n: No such file or directory` in the
  vocabulary pass. Harmless, but it suggests that check is not scanning what it
  thinks.
- **`tkg/art/ui/ShipViewer.dc.html`:158** still shows an "Overbored — +2 damage,
  +1 heat" affix chip. Reference comp.
- **"Pip" means two unrelated things** — the heat indicator on a card face, and a
  step on the 1–10 attribute ladder.
- **The starchart's 48,000-rect ceiling.** Dragging costs ~27 ms. Getting under it
  means drawing the star field as one thing, which puts the deliberate "rotate
  THEN round" pixel-snapping at risk. Not urgent; do not do it casually.

---

## 11. Deliberately not in scope

- The difficulty ladder / galaxy temperature. Deferred — though §9 depends on it
  as a direction.
- Open ruling #11, extraction deckbuilder (`coop-design.md` §16.1).
- The 205 unwritten cards for the five gated manufacturers.
- **Content authoring for the option pool.** Phase 6 builds the machine;
  `ENCOUNTER_GENERATION.md` says how to fill it, and that is its own job.
