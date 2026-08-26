# Logical encounter generation

*Design brief, 2026-08-25. Numbers re-checked 2026-08-26 against `main` at
`dd998f8` (SaveGame VERSION **14**, PROTOCOL 8) with the real per-kind `density`
values. Line numbers will move; grep the quoted strings.*

**Reference, not tonight's work.** Phase 6 builds the option machine; this is how
to fill it. §0's recovery check is the one part worth doing early — see
`ROADMAP.md` §S0.

**Scope:** how an option gets chosen for a place, and how to author options so
they land where they make sense. `ENCOUNTER_REBUILD.md` builds the machine; this
says how to fill it without producing fourteen events that feel like four.

Read after `ENCOUNTER_REBUILD.md` §4–§5. Roadmap phase 6 onward.

---

## 0. Before anything: find the previous attempt

**This was done once and most of it is missing.** `docs/archive/events-batch-01-verification.md`
analyses content that is not in the repo:

- a seed CSV of ~100 events numbered to at least EVT-095, nine marked `deferred`
- `events/batch-01.md` — ~15 authored events, 46 outcome bands
- `events/EXPANSION.md` — the effect whitelist
- `events/README.md` — the authoring workflow
- `card-design.md` — including the §15 pile-on guard

`DEVELOPMENT_PLAN.md`:35 still carries B1 against them. **Check James's
branches and `git log --diff-filter=D --name-only` before writing anything.**
Re-deriving a hundred seeds that already exist is the most expensive mistake
available here.

Read the verification report either way. Its finding is the design problem in
one line:

> The whitelist's DEFERRED list reads like an inventory of batch-01's mechanics
> ... Roughly half of batch-01 consists of outcomes that want to be remembered
> later, *by design*. The ghost that keeps spending your name until you resolve
> it. The lane that stays open region-wide. The fence who prices you kindly for
> the rest of the run. **That is the best writing in the batch and it is
> precisely what the rule excludes.**

33% conformed. Not because it was written badly — because the contract forbade
continuity, and continuity was what made it good.

### The option model dissolves that conflict

The old rule — *every event must fully resolve within itself* — existed because
an event was a popup with nowhere to put lingering state.

An option has somewhere. **Options are placed on nodes, and `MapNode.taken`
already persists which ones are spent.** So:

- the ghost that keeps spending your name → an option that appears on other
  systems until you take the one that resolves it
- the lane that stays open → an option added to the nodes of a region
- the fence who remembers you → his own system's option list, changed

The post-mortem's recommendation (c), *promote run-state flags into the MVP*, is
largely obsolete. **The option system is the persistence layer**, and it is
better than a flag store because the state has a place on the map instead of a
key in a dictionary. A flag says *the lane is open*; an option list says *the
lane is open THERE*, and the player can see it.

This changes the authoring question from "what happens when you click this" to
**"what does taking this do to the galaxy."**

---

## 1. Three rules that survived contact — copy them verbatim

The verification found these held across all 46 bands. They are the cheap part
of the contract because they are already proven.

**The failure-domain rule.** *A ram costs hull; a sneak costs detection; a burn
costs heat. Botches surprise in degree, never in kind.* A player who chose a
quiet approach and takes hull damage for it learns that the game is arbitrary.

**The pile-on guard.** No BOTCHED band stacks two of {hull damage, malfunction,
combat entry}. One violation in 46 bands — it was working.

**Hard gates only for meter payments and physical impossibility.** Heat ≤ 1,
Heat ≥ 3, 120 credits. Everything else rolls on the `SkillCheck` ladder rather
than greying out the button. This is the same principle as the ladder's 5%
floor: *a desperate option is never a disabled button with extra steps.*

---

## 2. The axes are not independent, and two of them barely exist

`MapGen._roll_axes()` rolls `development` and `security`, derives `berths` from
development, rolls `fauna`, and then **derives `region` from all of them**
(`_derive_region`, :512). Region is a label over the other axes, not a peer.

**This makes some gates impossible and nothing will tell you.**

| Region | Implies | So these gates can never match |
| --- | --- | --- |
| FRONTIER | no berths, not fauna | `needs_berth`, `needs_fauna` |
| FAUNA | no berths, development ≤ OUTPOST | `needs_berth`, `min_development ≥ SETTLEMENT` |
| LAWLESS | berths ≥ 1, **security ≤ 2** | `min_security ≥ 3` |
| TERRITORY | exactly 1 berth, security ≥ 3 | `max_security ≤ 2`, multi-manufacturer options |
| COSMOPOLITAN | berths ≥ 2, security ≥ 3 | `max_security ≤ 2` |
| CORE | the goal node only | everything else |

### And the distribution is steeply uneven

Modelled over 600 galaxies across all fifteen kinds at `LAYERS = 15`, using each
kind's authored `density`:

| Region | Share of galaxy | rim | mid | deep |
| --- | --- | --- | --- | --- |
| COSMOPOLITAN | **46.7%** | 4.0% | 37.5% | 81.6% |
| LAWLESS | **31.3%** | 40.2% | 39.9% | 15.4% |
| TERRITORY | 11.1% | 13.3% | 16.5% | 3.0% |
| FRONTIER | 7.6% | 29.6% | 4.2% | 0.0% |
| FAUNA | **3.3%** | 13.0% | 1.8% | **0.0%** |

*Modelled, not measured in-engine — `_roll_axes` reimplemented in Python. The
shares are stable to a few tenths across seeds; treat them as the shape, not as
gospel. A `-- content` region histogram would settle it properly and is worth
adding when the gate validator below gets built.*

Galaxy size varies more than the region mix does: **Giant Elliptical 354 systems,
Dwarf Spheroidal 156.** An option pool sized for the median is thin on the big
shapes and repetitive on the small ones.

Because `development = depth * 4 ± 1.1` and berths follow development, the deep
galaxy is almost entirely COSMOPOLITAN and **FRONTIER and FAUNA do not exist
past mid-depth at all.**

**Consequences for authoring:**

- Ten beautiful FAUNA options would fill 3% of the galaxy. Write two or three.
- Anything gated to FRONTIER is rim-only content by construction. That is
  correct — it is the opening of the run — but budget it as such.
- **COSMOPOLITAN and LAWLESS are where the volume goes.** Nearly 78% between
  them. If those two feel repetitive, the game feels repetitive.
- Deep systems are overwhelmingly one region, so **`danger` and `development`
  carry the late-game variety, not `region`.** Gate deep options on those.

### Required: a gate validator

`-- content` or a new `-- optiontest` must fail on:

1. An option whose gates can never all be satisfied (the table above).
2. A region with fewer than N eligible options — repetition is the failure mode
   and it is detectable ahead of play.
3. Any tier with no eligible `fight`-tagged option, per the reward-class ruling
   in `ENCOUNTER_REBUILD.md` §5.

This is cheap and it is the only thing that catches a gate typo, because a
wrongly gated option does not error. It simply never appears.

---

## 3. Author archetypes, vary by voice

Do not write 200 bespoke options. Write **archetypes** and get variety from
gating and register.

Suggested starting set, each mapping to a reward class:

| Archetype | Tag | Pays | Wants |
| --- | --- | --- | --- |
| Strip the wreck | `salvage` | low-rarity modules, hulls, fragments | any; more deep |
| Work the claim | `claim` | materials, credits | low development |
| Answer the signal | `signal` | credits, archive, standing | any |
| Take the contract | `contract` | credits, standing | berths ≥ 1 |
| Pick the fight | `fight` | **modules and rarity** | any |
| Pay the toll | `contract` | costs credits, buys passage | security ≥ 3 |
| Read the archive | `signal` | archive entries | berths ≥ 1 |
| Run the blockade | `fight`/`signal` | passage, standing loss | LAWLESS |

**The variety comes from voice, and your setting is unusually well suited to
it.** `lore.md` §5 rules the archive primary sources with no narrator, so the
same mechanical option reads completely differently as a Probate filing, a
Redline scrawl, and a Verity warranty notice. One archetype × seven
manufacturers × a register each is a lot of apparent content for one mechanic —
and it makes manufacturer identity do work it currently does not.

**Gate first, then write.** The reason fourteen events feel same-y is not the
count — it is that `EventTable.pick_key()` reads none of the axes. An option
that could appear anywhere will feel like it appears everywhere. Write the gate
line, then the prose that fits it: a customs cordon needs security, a whale fall
needs fauna.

---

## 4. Weighting inside the gate

Gating decides eligibility; weight decides frequency. Keep them separate — an
option that is *possible* everywhere and *likely* nowhere is a different design
from one that is rare and precious.

- Roll from `Rng.derive(&"options", n.index)`. Positional, so every machine
  agrees. See `ENCOUNTER_REBUILD.md` §3.
- **Draw without replacement within a system.** Two "strip the wreck" options at
  one node reads as a bug.
- **Damp repeats across a run.** With ~287 systems and 25–35 jumps, an option
  drawn uniformly will recur. Options carry an id; the simplest damper is to
  halve the weight of anything already taken this run. Store on the run, not the
  node — this is the one piece of genuine run-state the model needs, and it is
  one integer per option id.
- **Reserve a slot for continuity.** If a placed option (§0) is eligible here, it
  takes one of the 2–4 slots rather than competing on weight. A ghost that might
  not show up is not a ghost.

---

## 5. Authoring order

**Ten before a hundred.**

1. Machine — phase 6, per the roadmap.
2. Contract — §1's three rules, the reward classes, the gate table from §2.
3. **Ten options**: three archetypes × two regions, one with a check, one
   exclusive pair, one placed continuity option. Enough to exercise every part
   of the model.
4. `-- sim runs=500` with the option policy from phase 7. **This is what tells
   you whether 2–4 options at 25–35 jumps is the right density**, and that
   number should be settled by play before anyone commits to volume.
5. Then batch, weighted toward COSMOPOLITAN and LAWLESS per §2.

---

## 6. Open

- **Where the archetype/voice split lives in data.** One option per
  manufacturer-variant, or one option with a voice table keyed by
  `n.manufacturer`? The second is less to author and less to gate; the first is
  easier to write well. Recommend the second, with an escape hatch for options
  that are genuinely specific to one manufacturer.
- **How far continuity reaches.** An option placed on "the nodes of a region"
  needs a rule for how many and how far, or one choice quietly repaints a third
  of the galaxy.
- **`card-design.md` §15 blocked batch-02** pending a ruling on EVT-092, and the
  verification found EVT-092 was never authored. That block is nominally still
  live, in a file that no longer exists. Close it explicitly rather than letting
  it be forgotten by accident.
- **PG-13 and register rules held** in batch-01 and should carry forward — no
  profanity, no gore, and the endangered kid in EVT-084 survives every band she
  appears in. Worth restating in the contract since the file that held them is
  gone.
