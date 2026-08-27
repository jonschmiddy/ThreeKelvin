# ROADMAP — read this first

*Originally written 2026-08-25 as a routing document. **Rewritten 2026-08-26
after the S-phase session**, against `main` at `a5db9c1`. Phases 0–5 done, phase
5 **deleted** rather than parked, and the S-phases resolved — mostly by
dissolving. §1 is the state of the world; §2 is what is next.*

This is the index. Every other file in this bundle is linked from here.

---

## 0. The bundle

All of it now lives in `docs/briefs/`, committed at `f7cf04e`.

| File | What it is | Status |
| --- | --- | --- |
| `ROADMAP.md` | this index and the phase tracker | live |
| `ENCOUNTER_REBUILD.md` | options replace node types; the phase 6–8 design | ⬜ **next** |
| `ENCOUNTER_FLOW.md` | **what the player sees** — arrival to departure | ⬜ phase 8 |
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

**Repo:** `main` at `a5db9c1`, pushed. `SaveGame VERSION 14`, `PROTOCOL 8`,
`validate.sh` passing.

**⚠ `VERSION` IS ALREADY 14.** `be37b3e` stamped it during the attributes work.
**Phase 6 bumps 14 → 15.**

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
| `-- chartbench` / `-- zoomshot` | frame cost; zoom ladder + density profile | **yes** |

**`--headless` never emits `frame_post_draw`.** A harness that draws must run
windowed or it hangs looking like a bug.

**⚠ `-- sensordump` defaults to a Giant Elliptical, `arms = 0`** — the one kind
that cannot show an arm effect. Pass `kind=0` for a Grand-Design Spiral. Two
measurements were taken on the wrong kind before this was noticed.

---

## 2. WHAT IS NEXT

**Phase 6.** The S-phases are done and S3 dissolved, so `ENCOUNTER_REBUILD.md`
§4–§5 is the front of the queue. It bumps `SaveGame` **14 → 15** and extends
`content_fingerprint`, both in the same commit as the thing they describe.

**Do not start it tired.** Stamping a save format at the end of a long session is
how a bad night's work becomes a migration.

| | Job | Read |
| --- | --- | --- |
| 6 | Option model, table, roller | `ENCOUNTER_REBUILD.md` §4–§5, §5a |
| 7 | Option policy in the sim | `ENCOUNTER_REBUILD.md` §8 |
| 8 | Collapse `NodeType`, ambush becomes an interrupt | §6–§7 · **`ENCOUNTER_FLOW.md`** |
| 9 | Tune, including **sector difficulty** — see §7 | §8, `GALAXY_SCALE.md` §6 |
| 10 | **G §5** — chart primer | `GALAXY_SCALE.md` §5 |
| 11–12 | **L** — live card faces, then the targeting line | `LIVE_CARD_NUMBERS.md` |

**Phase 7 is not optional.** Without an option policy the sim takes everything,
overstates income, and never exercises the exclusivity that is the point of 6.

**▲ E and L both make large edits to `SectorScreen.gd`** — one 1,221-line file
that is both the arrival screen and the combat screen. **Sequence them.**

**G §5 comes after phase 8**, which deletes four of the chart's six icon entries.

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
| 6–8 | **E** — the encounter rebuild | ⬜ **next** |
| 9 | Tune, incl. sector difficulty | ⬜ |
| 10 | **G §5** — chart primer | ⬜ |
| 11–12 | **L** | ⬜ |

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
