# ROADMAP — read this first

*Originally written 2026-08-25 as a routing document. **Rewritten 2026-08-26
after the S-phase session**, against `main` at `a5db9c1`. Phases 0–5 done, phase
5 **deleted** rather than parked, and the S-phases resolved — mostly by
dissolving. §1 is the state of the world; §2 is what is next.*

***Updated 2026-08-30.** Materials became items — the one ⬜ marked **next** — and
§1 was seven save versions out of date. What is left before the tune gate
reopens is **placement**, then **star features**, then G §5, then L.*

This is the index. Every other file in this bundle is linked from here.

---

## 0. The bundle

All of it now lives in `docs/briefs/`, committed at `f7cf04e`.

| File | What it is | Status |
| --- | --- | --- |
| `ROADMAP.md` | this index and the phase tracker | live |
| `ENCOUNTER_REBUILD.md` | options replace node types; the phase 6–8 design | ✅ landed |
| `ENCOUNTER_FLOW.md` | **what the player sees** — arrival to departure | ✅ all nine rulings |
| `ENCOUNTER_AUTHORING.md` | **how to write more** — pipeline, rules, audit | reference |
| `ENCOUNTER_GENERATION.md` | filling the option pool; gating, archetypes | reference |
| `batch-02-draft.md` | first six authored options, plus six ported events | draft |
| `batch-03.md` | twenty more, aimed at the coverage gaps | draft |
| `encounter-prototype.html` | playable feel-test: 10 systems, 29 options | tool |
| `LIVE_CARD_NUMBERS.md` | live card faces and the targeting line | ⬜ unblocked |
| `GALAXY_SCALE.md` | map scale, declared shape, the chart primer | §1–§4 ✅ · §3 **void** · §5 ⬜ |
| `HEAT_REWORK.md` | dissipation amplifies venting | ✅ landed (§3 reverted) |
| `SIM_INSTRUMENT_FIX.md` | the strand counter measured the wrong set | ✅ **done, and it was right** |
| `S3A_FUEL_SWEEP.md` | the fuel sweep spec | ❌ **dissolved — never needed** |

---

## 1. STATE OF THE WORLD

**Repo:** `main` at `76001d1`, two commits ahead of `origin`. `SaveGame VERSION
24`, `PROTOCOL 8`, `validate.sh` passing.

**⚠ `VERSION` MOVES OFTEN AND THE DISCARD IS THE MIGRATION.** It has gone 14 → 24
since this file was written; `SaveGame.gd`'s own header carries a line per bump
and is the place to read them. The two that matter to anyone reading this for
context: **21–22** renamed the container class twice (`hoards` → `flotsam` →
`jetsam`) and **24** deleted the material ledger. A mismatch refuses the load, so
every one of those is a discarded save rather than a migration path.

**Constants that moved on 2026-08-26** — several of these are new, and the old
values appear all over the older briefs:

```
MapGen:    LAYERS 15   RING_SPACING 0.1157   DOOR_SHARE 1.00   MIN_DOORS 2
           ring weight 0.80–1.80   (was 0.14–3.3)
           arm pull cap 2.0 neighbour widths   (was 0.6)
RunState:  JUMP_RADIUS 0.18   (was derived from local density)
           SENSE_FLOOR 1.5   SENSE_REACH 0.25
           THRUST_REACH 0.04, capped 1.4
```

**Instruments.** *"It feels wrong" is not a number.*

| Command | Answers | Window? |
| --- | --- | --- |
| `-- sim seed=1000 runs=500` | the balance gate; per-kind table, economy, strand split | no |
| `-- maptest` | every ring has a door, **and the core can be FLOWN to** | no |
| `-- shipdrift` | does the ship move when its loadout changes | no |
| `-- sensordump seed=N kind=N` | real galaxy geometry as JSON | no |
| `-- fogshot` | what the chart shows, and **why each system is lit** | **yes** |
| `-- sectorshot [group\|spent\|hover\|open=N\|take=N]` | the drawer in every state it has | **yes** |
| `-- sectorshot combat ask{hail,flee} [resolve]` | the exit panel, and pressing through it | **yes** |
| `-- transfertest` · `-- materialtest` | containers and materials, on what is DRAWN | no |
| `-- chartbench` / `-- zoomshot` | frame cost; zoom ladder + density profile | **yes** |

**`--headless` never emits `frame_post_draw`.** A harness that draws must run
windowed or it hangs looking like a bug.

**⚠ `-- sensordump` defaults to a Giant Elliptical, `arms = 0`** — the one kind
that cannot show an arm effect. Pass `kind=0` for a Grand-Design Spiral. Two
measurements were taken on the wrong kind before this was noticed.

---

## 2. WHAT IS NEXT

**Phase 9.** E is done, the pool is 44 deep, and the loop is finally worth
measuring. `SaveGame` is at **17**.

### ▸ RULING — win rate is not a gate until every system is in

**Ruled 2026-08-27, by Jonathan, in as many words:** *"I'm not worried about win
rate until all systems are in."*

So the number below is a READING, not a target, and a six-point move in it is not
a reason to change a design decision. Half the systems that will price the loop
do not exist yet — ~~materials are a credit shim~~ (**landed 2026-08-30**), there
is no placement mechanic, star features are a proxy gate, ascension levels are
unbuilt. Tuning against a loop with pieces missing bakes the missing pieces into
the numbers.

**Re-affirmed 2026-08-30, unprompted and in the same words**, when the materials
number came in. The ruling is holding on its own.

**What still IS a gate, unchanged:** a galaxy kind at **0%** is a broken loop and
not a difficulty setting; stranding above a percent or two is a bug; `errors 0`
is not negotiable. Those say something is wrong. A win rate of 28 says the game
is hard today.

**When the gate comes back:** phase 9 moved behind the remaining systems for this
reason. Tune last, against the whole thing.

### The phase 9 baseline — 500 runs, 2026-08-27

```
runs 500 · wins 139-146 (28-29%) · errors 0
avg jumps 14.3 · avg kills 3.5 · avg danger reached 7.47
options: 0.33 opened a fight
spread: Collisional Ring 44% down to Grand-Design Spiral 20% (24 points)
```

**Read this next to the number it replaced.** Before the option review the same
build measured **35%** (177/500). The review cut two options and made a third
risky, and that cost **six points**. It is not noise: 29% and 28% on consecutive
500-run samples, and **500-run noise is about ±1** — far tighter than the ±4 a
200-run reading carries.

**What the cuts actually removed**, which is the part worth keeping in mind
before cutting content again:

- `coolant_seller` held the pool's **only permanent +3 heat cap**. Reactor-cook
  went from 28% of deaths to **31%**, and is now level with hull loss as the
  leading killer.
- `cold_sleeper` was a fuel and exotic source on an ungated option.
- `whale_fall`'s "let it rest" paid a free **+8 hull** and now pays nothing; its
  harvest can cost 11 hull where it previously could not hurt you.

**The reward was load-bearing, the wrapper was not.** A permanent heat cap is the
only thing in the pool that answers the leading cause of death, and it left the
game because the fiction around it was weak. If 28% is too low, re-homing that
reward on a better-written option is the first move and a one-line change to the
win rate's biggest lever.

**Take 500 before concluding anything.** A 200-run reading is worth ±4 points,
measured — three consecutive runs of one build gave 20%, 13%, 16%.

**What phase 9 should look at, in order:**

0. **Whether 28% is the target**, and if not, where the heat cap goes. See above.
1. **`avg kills 3.5`, down from 6.6.** Fights are now 0.29 an option rather than
   a node type, and this is the number that moved most. Is a run with three
   fights in it the game we want? That is a design question, not a bug — but the
   combat system is a lot of machinery to exercise three times.
2. **`credits: -1 net at stations per run`.** The economy is almost exactly flat
   at the one place designed to move it. Worth knowing whether that is the
   intent.
3. **§9a, the hellbender's food** — 3.79/run now, down from 4.36 but still well
   above the 2.24 the old type bag produced.
4. **Sector difficulty** — `GALAXY_SCALE.md` §6, parked since phase 8.

### Deleted in the same pass

- **The anchor floor.** Its premise — "a system with neither is a system with
  nothing in it worth crossing a galaxy for" — was written against a five-option
  table and is false at 44: `no system is left with nothing to do` passes without
  it. It had stopped being scaffolding and become a fight-density knob firing on
  half of all systems. Density is a weight, not a swap that overrides the roll.
- **`EventTable.gd`.** Emptied by the batch-04 port and deleted. Its two live
  tools now read `OptionTable`: `-- checks` verifies the odds ladder against four
  times as much content, and `rngtest` fingerprints the option roll. `event_key`
  stays on `MapNode` and in the save until the next version bump.

| | Job | Read |
| --- | --- | --- |
| 6 | Option model, table, roller | ✅ `SaveGame` 15 |
| 7 | Option policy in the sim | ✅ |
| 8a-1 | Ambush becomes an interrupt | ✅ `SaveGame` 16 |
| 8a-2 | Collapse `NodeType` to START/SYSTEM/STATION/PULSAR/CORE | ✅ `SaveGame` 17 |
| 8b | The arrival screen — a system renders its whole list | ✅ all nine rulings |
| — | Content — batch 04, thirty options | ✅ pool is **44** |
| 9 | **Tune** — see the baseline below | §8, `GALAXY_SCALE.md` §6 |
| — | **Materials become items** — hold cells, selling, jettison, the shim deleted | ✅ `SaveGame` 24 |
| — | **Placement** — unblocks the five held options | `BLOCKED_PLACEMENT.md` ❌ **missing** · ⬜ **NEXT** |
| — | **Star features** — a real pulsar gate, not `min_danger 4` | `the_sweep`'s note |
| 10 | **G §5** — chart primer | `GALAXY_SCALE.md` §5 |
| 11–12 | **L** — live card faces, then the targeting line | `LIVE_CARD_NUMBERS.md` |
| 9 | **Tune LAST** — hellbender's food, then sector difficulty | §8 · **§9a below** |

**Phase 7 is not optional.** Without an option policy the sim takes everything,
overstates income, and never exercises the exclusivity that is the point of 6.

**▲ E and L both make large edits to `SectorScreen.gd`** — one 1,221-line file
that is both the arrival screen and the combat screen. **Sequence them.**

**G §5 comes after phase 8.** The chart key is now START · SYSTEM · STATION ·
PULSAR · CORE — five entries, down from seven.

### What 8a-2 changed in the numbers

Against `8e476ff`'s 500-run baseline, at 200 runs:

| | before | after |
| --- | --- | --- |
| wins | 35% | **17%** |
| avg jumps | 16.1 | 14.6 |
| avg kills | 6.6 | 6.8 |
| lowest kind | 19% | 6% |
| derelicts eaten | 2.24/run | **4.36/run** |

**A 200-run sim is worth ±4 points, measured.** Three consecutive runs of the
same build: **20% · 13% · 16%**. So a single 200-run reading cannot tell a
four-point change from nothing, and the row above is a band, not a number —
`8e476ff`'s baseline was 500 runs for this reason. **Take 500 before concluding
a change moved the win rate, and never tune against one 200-run delta.**

**Fight volume did not move** — the game got harder somewhere else, and the
hellbender row is the strongest lead. Its food used to be `NodeType.DERELICT`,
**4 of the 40-entry type bag**; it is now "a system offering a `salvage` option",
and with `dead_hull` at weight 14 in a seven-option table that is most systems.
The set piece roughly doubled its intake without anyone deciding it should.

Two knock-ons were found and fixed while landing this, both worth recording
because neither was visible from the type change itself:

- **`system_has_tag` had to roll the system before reading it.** Contracts look
  three layers ahead and the hellbender scans the whole map, so both were asking
  about systems nobody had flown to — whose `options` were still empty. It
  answered "no fight anywhere" and the hunt contract stopped being findable.
- **Winning an option's fight consumed the whole system.** Fine when an EVENT
  node held one event; wrong when a system holds about three options, because the
  two the player had not reached yet silently stopped existing. Worth 2.4 jumps
  and the last 0% galaxy kind.

**Not tuned here.** Phase 9 owns it. See §9a.

### What materials-as-items cost, measured 2026-08-30

The shim is gone: `MaterialTable.grant` hands over an object and the parallel
`Run.materials` ledger is deleted, so `material()` counts the hold and
`spend_material` takes things off it. The fabricator, the station counter and
the `needs_material` gates followed without being touched, which is what the
note promised when it put the shim in one function.

**Wins fall 26% → 15% at 300 runs, and it is not the simulator's fault.** That
was the obvious suspicion — `Policy.HOLD_LIMIT` is 4 and counts ITEMS while
hulls hold 8/12/16 CELLS, so the model looked like it was binning a one-cell
artifact to keep a fourth gun. Three arms, 900 runs:

| cap | wins | looted/run | hull deaths | reactor |
| --- | --- | --- | --- | --- |
| 4 items *(shipped)* | 15% | 7.2 | 112 | 62 |
| 8 cells | 13% | 6.6 | 101 | 88 |
| 12 cells | 14% | 6.5 | 104 | 82 |

All three are inside one standard error. **The cap unit makes no difference**,
and loosening it from 8 to 12 changed nothing either — so the cap was never the
binding constraint. `Policy` was reverted to 4 items; the change had not earned
its place.

Which points at the answer being the game, working as designed: the constraint
that bites is the **real hull grid**. Crates take real cells, fewer modules fit,
ships arrive worse-armed. Deaths are 44% hull and 24% reactor with stranding at
0.7% — these ships lose fights, they do not go broke. That is what "loot costs
space" means, and it is the point of a spatial hold.

**Do not tune against this.** See the ruling above; it is a reading.

**Unexplained, and left standing:** reactor deaths were 62 in the shipped arm and
82–88 in both cell arms — well beyond noise, and a cargo cap should have nothing
to do with overheating. Also `credits: −4 net at stations per run` and **zero
fuel bought across 2.5 station visits**, which predates all of this and means
the sim barely exercises the counter that materials exist to be carried to.

---

### §9a — the hellbender's food supply, first thing to price in phase 9

**Nobody decided this.** It fell out of the type collapse and was found by
reading the sim report, not by playing.

The hellbender eats wrecks. Its food used to be `NodeType.DERELICT` — **4 of the
40-entry type bag, 10% of systems**. It is now "a system offering a `salvage`
option", and with `dead_hull` ungated at weight 14 in a seven-option table, that
is most of them. Measured: **2.24 derelicts eaten per run → 4.36**.

That is not a difficulty knob anyone turned. It is a constant that used to be
written in the type bag and is now written in `OptionTable`'s weights, where
nothing was watching it.

**The trap in fixing it.** The obvious lever is `dead_hull`'s weight, and that is
the wrong one — it would thin out salvage for the PLAYER in order to slow the
hellbender down, which are two different problems sharing a tag. The lever that
matches the intent is the feed rate in `RunState`, or a scarcity rule on what
counts as food. Price it against the 10% the old bag implied.

**Do not tune this before content lands.** The table is seven options deep and
`dead_hull`'s share of it is an artefact of that. At thirty options the number
moves on its own, and tuning against the thin table would bake the artefact in.

---

## 3. WHAT THE S-PHASES FOUND

The regression this document used to describe — 38.8% stranded, a fuel crisis,
a 0% tail — **was four bugs, and none of them was the fuel economy.**

| | morning `dd998f8` | now `a5db9c1` |
| --- | --- | --- |
| stranded | 38.8% *(reported)* | **0.0%** |
| unwinnable kinds | 2 | **0** |
| lowest kind | 0% | **19%** |
| wins | 19% | 35% |
| jump range | swung 5× with density | **fixed 0.18** |

1. **The strand counter measured the wrong set.** It counted the policy giving
   up, not the run ending. 46% of reported strands were ships that could fly.
2. **The policy routed on `links`.** The player routes on a radius and nothing in
   the jump path reads `links` at all. Fixing it took stranding to **zero** and
   proved Barred Ring Spiral was never a hard galaxy.
3. **Criterion 1 was never implemented.** Sensors decided what was *drawn*, not
   what could be flown to.
4. **The core was reachable but unsensable** on ring galaxies. `reachable_from`
   is symmetric, `chart_from` is not, so the objective itself was invisible and
   ships circled the rim for 233 jumps.

Full numbers with attribution: **`docs/sim-baselines.md`**, which now records
every step of the night.

---

## 4. Phases

| # | Phase | Status |
| --- | --- | --- |
| 0–2a | baseline, per-kind reporting, **H** | ✅ |
| 3–4 | **G** — `LAYERS 15`, `density`/`reach`, D1 | ✅ |
| 5 | **G** — sparse coreward links | ❌ **DELETED — see §5** |
| S0–S3 | docs, instrument, re-measure, fuel ruling | ✅ done; **S3 dissolved** |
| 6–8 | **E** — the encounter rebuild | ✅ |
| — | Content — batch 04, reviewed | ✅ pool **42** |
| — | **Materials as items** | ✅ 2026-08-30 |
| — | Placement · star features | ⬜ **next** |
| 10 | **G §5** — chart primer | ⬜ |
| 11–12 | **L** | ⬜ |
| 9 | Tune — **moved to last**, see the ruling | ⬜ |

---

## 5. Why phase 5 is deleted, not parked

`GALAXY_SCALE.md` §3 wants sparse coreward doors so that *"crossing a ring is how
you find the way down"*. **That cannot work, and it never could.**

Doors are `links`. Nothing in the jump path consults `links` — `can_jump_to` is
`sensed` plus `reachable_from` plus fuel, and `reachable_from` is a radius. The
chart's own neighbour list is `in_range()`. **Thinning doors changes which lines
are drawn and nothing else.**

The 98% stranding once attributed to it was entirely the simulator's link-routed
policy. `DOOR_SHARE` stays at 1.00. **`GALAXY_SCALE.md` §3 is void** — read it
for the goal, not the mechanism.

What replaced it: the arm clustering in §6, and sector difficulty in §7.

---

## 6. What the briefs got wrong

Goals right; the mechanisms mostly did not survive measurement.

- **`HEAT_REWORK.md` §3's target is stale by an order of magnitude** — aims at
  0.32 average arrival signature; measured 0.04.
- **Full-rate transit cooling was reverted.** Dissipation-amplifies-venting is
  the half that landed, and it worked: post-fight signature 0.14 → 0.32.
- **The vent thresholds are inert.** Galaxy variance swamps the dial.
- **`GALAXY_SCALE.md` §0's "a run is eight jumps long" is a minimum.** The
  flyable minimum measures 6.1; a competent player takes ~16.
- **`GALAXY_SCALE.md` §3 is void.** See §5.
- **`S3A_FUEL_SWEEP.md` answers a question that does not exist.** Its §0 was
  right that `FUEL_TOPUP` had to be swept first — but the shortfall it was built
  to investigate was the strand counter lying. Runs end with **88% of the tank**.

### The heat framing, corrected

**Korvan run cold. That is the plan.** All three heat-scaling cards belong to
Solari, who are 7/40 authored and not in `ACTIVE_MANUFACTURERS`.

---

## 7. Run length — the one open design problem

**~16 jumps against `GALAXY_SCALE`'s 25–35.** Everything else on the balance
sheet is healthy: nothing strands, no kind is unwinnable, the spread is 45 points
with a floor of 19%.

**Ruled 2026-08-26: fix it with sector difficulty, not geometry.** Deep sectors
should be too hard for a six-jump ship to survive, so the fast dive stays
*available and lethal* rather than walled off. That preserves the player's agency
and rewards a strong build — a geometric wall forces the long route on everyone.

The curve is **linear** today:

```gdscript
var ring_danger := 1 + int(round(layer * float(DANGER_MAX - 1) / float(maxi(1, LAYERS - 2))))
```

`1 + round(layer * 9 / 13)`, jittered ±1, capped at 10. The direction wanted is
**exponential** — the middle exponentially harder than the rim, so reaching it
means farming the sectors between.

**Parked until phase 8.** Difficulty is meaningless until encounters are what
they are going to be, and tuning it twice is the argument this document already
makes for doing G before E.

---

## 8. Open decisions

**D1 — anisotropy. ANSWERED: measure un-squashed.** Landed in phase 4. Its
visible consequence — the reach is an **ellipse**, so a system below you is
1/squash further than it looks — is now drawn on the chart.

**D2 — hand reorder. ANSWERED: drop it.** Phase 12 is unblocked and becomes a net
deletion. See `LIVE_CARD_NUMBERS.md` §3a.

**S3 — fuel income. DISSOLVED.** Not a decision any more; there is no shortfall.

**The flyability margin — ACCEPTED as roguelite variance.** `MapGen` does not
*guarantee* a flyable route, it happens to leave one: arm cap 4.0 fails
`-- maptest` on one Grand-Design Spiral in 120 while 6.0 draws a near-identical
galaxy and passes. At 2.0 there is plenty of room. Ruled 2026-08-26 that
sometimes you get unlucky and that is the genre.

---

## 9. Standing constraints

- **Ship Korvan-only, to a small group of friends, months out.** Korvan is not
  finished. Core systems before more manufacturers.
- **Win rate is deliberately de-prioritised.** Ascension-style difficulty levels
  are planned, so a generous level 1 is the design. *That does not extend to a 0%
  kind, which is a broken loop* — and there are none now.
- **No PixelLab generation without explicit approval.** 39 modules and 73 cards
  undrawn, 8 sprites awaiting a verdict.
- **The word is "manufacturer".** `validate.sh` enforces it — and as of `f7cf04e`
  the docs half of that guard **actually runs**; it had been failing open on a
  stray `\n` for as long as it had existed.

---

## 10. Known drift to fix in passing

- **`design-doc.md`:116-118** describes affixes as modifying card behaviour, with
  three examples now impossible by design. *Nothing automated watches semantic
  claims.*
- **`GalaxyGen.gd` header** claims galaxy shape cannot move a jump or a fuel cost.
  It can, and `reach` now does so more than ever: with a fixed jump radius, a
  galaxy authored large is one that takes more hops to cross.
- **`tkg/art/ui/ShipViewer.dc.html`:158** still shows an "Overbored" affix chip.
- **"Pip" means two unrelated things** — the heat indicator on a card face, and a
  step on the 1–10 attribute ladder.
- **The starchart's 48,000-rect ceiling.** Dragging costs ~25 ms. Getting under it
  means drawing the star field as one thing, which risks the deliberate "rotate
  THEN round" pixel-snapping. Not urgent.
- **`Policy.choose_jump` does not plan.** It picks from what is reachable this
  instant, which is why the simulator could not measure live sight at all. Any
  future question about *routing* needs a policy that looks more than one hop
  ahead.

---

## 11. Deliberately not in scope

- The difficulty ladder / galaxy temperature — though §7 now depends on the
  per-sector half of it.
- Open ruling #11, extraction deckbuilder (`coop-design.md` §16.1).
- The 205 unwritten cards for the five gated manufacturers.
- **Content authoring for the option pool.** Phase 6 builds the machine;
  `ENCOUNTER_GENERATION.md` says how to fill it, and that is its own job.
