# Authoring encounter options — the method

*Written 2026-08-26, offline, after writing 26 options across `batch-02-draft.md`
and `batch-03.md`. This is the recipe, including the parts that went wrong.*

**Read with:** `ENCOUNTER_GENERATION.md` (where options come from and how they
are gated), `ENCOUNTER_FLOW.md` (what the player sees, nine rulings),
`batch-03.md` (twenty worked examples).

---

## 1. The pipeline — one source, two outputs, one audit

**Never hand-write the same option twice.** The markdown and the prototype data
drifted the first time and it took a syntax error to find out.

```
  batch03.py          one Python list of dicts. THE source.
      │
      ├── emit.py ──────────► batch-03.md          (human review)
      └── emit_js.py ───────► prototype JSON       (feel-testing)
                                   │
                                   └── audit.js    (headless, node)
```

**Why Python and not GDScript:** the pool wants 60–100 options and none of them
can be checked in the engine until phase 6 exists. A flat data structure that
emits both a readable document and a runnable prototype lets the writing be
reviewed and *played* before there is anything to load it into.

When phase 6 lands, add a third emitter that writes the GDScript table. **The
prose never gets retyped.**

### The audit is not optional

Run the prototype headless with a stubbed DOM and walk every option. Do not
eyeball it — the first pass had a missing band and a broken object literal that
looked fine on screen.

```js
// what it must check, at minimum
every checked choice has all four bands MET/CLEAN/PARTIAL/BOTCHED
every unchecked choice has flat text
every option has a full body
no MET band pays nothing                    // the Customs cordon fault
every option has something to lose by leaving   // Ruling 9
every grouped set has a decline row             // the free-exit rule
attribute checks are counted and reported       // spot the overweight one
```

**This is the spec for `-- optiontest`.** Everything above is checkable without
running a game.

---

## 2. The data shape

```python
opt(id="the_braid",                    # StringName. NEVER the display title.
    label="The braid",                 # the row
    tags="salvage",                    # fight | salvage | signal | claim | contract
    group=None,                        # shared string = mutually exclusive
    weight=7,                          # roll weight inside the gate
    gate="regions: FAUNA, FRONTIER · needs_fauna",
    teaser="Something large is moving through, and moving fast.",
    full="...two paragraphs...",
    places="paid_in_full",             # optional: places another option deeper
    choices=[...])
```

`id` is identity. `EventTable.by_key()` matched on the **title string**, so
renaming "Whale fall" invalidated every save that rolled it. Do not repeat that.

A choice is either **checked** (four bands) or **flat** (one outcome), plus
optional `gate_credits`, `fight`, `decline`.

---

## 3. Writing an option — the four things it needs

Most of my first six failed on the middle two, and it took a reader to notice.

### A cause

Why does this exist, and why is nobody here? *"Somebody seeded this approach and
never came back to sweep it."* *"Cygnet built it, staffed it, and pulled the
staff out four years ago when the seam stopped paying. Nobody told the
refinery."*

Without a cause an option is a noun with a skill check attached.

### A clock

What happens if you do nothing? *"The board will settle it in about nine days.
The wreck will not last nine days."* *"The gauges give you perhaps four minutes."*
*"Forty minutes is enough to reach the rock. It is enough to strip the drone. It
is not obviously enough to do both."*

### A reason it is YOU

*"She needs somebody with no berth here."* *"That is a narrow description and you
fit it."* The player is a specific ship with specific attributes; say why that
matters.

### Something lost by leaving — `ENCOUNTER_FLOW.md` Ruling 9

**PLOT NEXT JUMP is always live, so nothing can block the exit.** Any option
whose premise is *you have to get past me* is lying.

> **The test: if the player walks away, what do they not get?**
> If the answer is "nothing", the option is a wall and the wall is imaginary.

Both cordons were written as walls and both had to be re-cut. **This is a
porting hazard too** — every one of the fourteen legacy events assumed the event
*was* the whole system.

---

## 4. The bands

### Failure stays in its domain

Carried from the batch-01 post-mortem, where it held across all 46 bands.

| Check | Failure costs | Never costs |
| --- | --- | --- |
| Hull | hull, all the way down | fuel, exposure |
| Thrust | fuel | hull |
| Maneuver | hull (you hit something) | fuel |
| Thermal | heat | hull |
| Sensors | being wrong — credits, a wasted trip | hull |
| Stealth | being seen — fines, exposure | hull |

**Botches surprise in degree, never in kind.** A player who chose the quiet
approach and takes hull damage learns the game is arbitrary.

### PARTIAL is the band they will read most

The ladder splits failure evenly, so at four short it is **47.5% PARTIAL**.
`SkillCheck.gd` says it outright — *partial is where the design effort goes.*

Give it its own shape, not a smaller BOTCHED: *the wide route at speed*, *a reply
you will never send*, *cutting by hand after that*, *one pass, an armful, and a
cabin you cannot stand in.*

### MET must pay

If the best outcome is *nothing bad happens*, the option is a wall — see
Customs cordon in §3. MET should be the version where it goes right, not the
version where it fails to go wrong.

### The pile-on guard

No BOTCHED band stacks two of **{hull damage, malfunction, combat entry}**. A
fine plus a fight is fine; hull plus a fight is not.

### Hard gates only for meters

Credits, fuel, heat thresholds. Everything else rolls the ladder, because the 5%
floor means **a desperate option is never a disabled button with extra steps**.

---

## 5. Reward classes

`ENCOUNTER_REBUILD.md` §5. Modules and rarity come from **fights and the wrecks
fights leave**. Everything else pays in credits, fuel, materials, archive
entries.

The rarity ladder already does the high-risk half by itself —
`LootGen.roll_module()` refuses EPIC below danger 3 and LEGENDARY below danger 4.
**Do not duplicate that elsewhere**, or the ladder leaks.

Only two materials exist: `exotic` and `relic`. The archive is **positional** —
`Archive.at_node()` derives from the node index, so an option can only recover
the document that is already here, never conjure one.

**Standing is not a reward.** It exists, but contracts are its only writer, it
has one effect capped at 20% on the bid, and it is never displayed. A
consequence the player cannot see is not a consequence.

---

## 6. Voice

- Second person, present tense, **flat about consequences**. *"Forty units, and
  most of your paint."*
- **One concrete detail per band**, carrying the tone instead of an adjective. A
  cutting head. Eleven minutes. A man in a chair. Once every ninety seconds.
- **Institutions are polite and immovable.** Nobody shouts. The Verity service
  loop is the model: not threatening, just still running.
- **The declining option is never punished and never blank.** *"The long way.
  Nothing happens on it, which is the point."*
- **Fiction lives in the body and the outcome text. Labels that explain a RULE
  are plain** — `BECOMES UNAVAILABLE`, not *spoken for, if you do*.
- PG-13. No profanity, no gore. Nobody is harmed on screen.

### Register range

Not everything is dry. The pool needs some sad (`the_memorial`), some warm
(`paid_in_full`), some funny (`cold_labour` — a yard crew testing a cutter on
your hull because they would rather learn on somebody else's plating).

---

## 7. What I reach for when I run out of ideas — avoid these

Written down because the failure is invisible from the inside. Past a dozen
options in one sitting the same shapes start reappearing with the nouns changed.

**Overused already:**
- a wreck with something valuable in it
- two parties who disagree and are not present
- a thing with a countdown measured in a specific number of days
- paperwork as the obstacle — boards, filings, dockets, registries

**Underused, go here instead:**
- options where the other party is *present and talking*
- environment with no antagonist at all (`ice`, `flare_shelter`)
- work that is honest and dull and pays (`tug_work`)
- something that wants nothing from you (`the_memorial`)
- a party who is *wrong* rather than hostile
- fauna, machines, and things that were never people

**Twelve to twenty per sitting, then stop and have it read.** Quality degrades
before the writer notices. The first six needed three correction passes — standing
removed, bodies rewritten for cause and clock, two re-cut for Ruling 9 — and
every one of those corrections came from a reader.

---

## 8. Aim each batch at the gap, not at whatever occurs to you

After 26 options:

| attribute | checks | |
| --- | --- | --- |
| Sensors | **7** | overweight — a Sensors build reads more of the galaxy than any other |
| Thrust | 4 | |
| Maneuver | 4 | fixed by batch-03 |
| Stealth | 3 | thin |
| Hull | 3 | thin |
| Thermal | 3 | fixed by batch-03 |

**Next batch: Hull, Stealth, Thermal.**

Region targets follow `ENCOUNTER_GENERATION.md` §2 — COSMOPOLITAN 46.7% and
LAWLESS 31.3% of the galaxy, so that is where volume goes. FAUNA is 3.3% and
does not exist past mid-depth; two or three options is the whole budget.

Every batch should also add **at least one placed option pair**. Continuity is
what the model exists for, and it is the first thing to get skipped because it
costs two options to deliver one payoff.

---

## 9. Before the next batch

**Run `ENCOUNTER_GENERATION.md` §0's recovery check.** A hundred-seed CSV and a
`batch-01.md` existed and are not in the repo. If it turns up in a branch, the
job becomes editing rather than inventing, and everything above applies to the
edit.
