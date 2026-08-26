# Encounter flow — the storyboard

*Written 2026-08-26, offline, against `main` at `dd998f8`. Line numbers move;
grep the quoted strings.*

**What this is:** one system, arrival to departure, beat by beat — and the four
UX decisions that walk forces. `ENCOUNTER_REBUILD.md` specifies the data model
and what collapses; **this specifies what the player sees.** Phase 8 builds it.

Read with `ENCOUNTER_REBUILD.md` §7 and `batch-02-draft.md`.

**Nine rulings, all made 2026-08-26.** §7 lists the two things still open.

---

## The worked example

A LAWLESS system, danger 4, security 2, one Verity berth. It rolls three options
from `batch-02-draft.md`:

- **OPT-004 Salvage rights** — group `wreck`
- **OPT-005 Still under warranty** — group `wreck`
- **OPT-003 The cordon** — independent

---

## Beat 0 — the chart, before you spend anything

Region tint, danger, security, berth chips, fuel cost. **No icon.** You know it
is LAWLESS at danger 4 with a Verity berth, and nothing about what is in it.

**You are buying information with fuel.** That is the whole reason the icon set
collapses to station / start / core in `ENCOUNTER_REBUILD.md` §7 — with icons,
route planning is shopping.

---

## Beat 1 — arrival

`Router.resolve_current_node()`, unchanged in order: log the arrival line, roll
the options, `reach_contract_target()`, autosave. Rolling before the save is what
makes arrival the safe point — the save is a bookmark, not a way to reject a
draw.

**Two things can pre-empt the list**, and neither consumes the system:

- **Ambush**, rolled against `Run.ambush_chance(n)` off the per-seat `Rng.foe`
  stream. After the fight the options are still here.
- **The hellbender**, if it is parked here. One button, no dock, no contact.

---

## Beat 2 — the strip becomes a list

Today `_build_quiet_strip()` (`SectorScreen.gd`:303-314) is one panel holding a
label and **one** button, with `_quiet_lines()` returning `[line, label]`. That
whole shape goes.

What the player sees:

```
  The lane is quiet and the board is not.

  ┌─ one of these ───────────────────────────────────────────┐
  │  A hull lies open across two claims.                     │
  │      SALVAGE RIGHTS                                      │
  │  A Verity plate, still transmitting.                     │
  │      STILL UNDER WARRANTY                                │
  └──────────────────────────────────────────────────────────┘

  Someone has strung a picket across the lane.
      THE CORDON

  PLOT NEXT JUMP
```

### ▸ RULING 1 — exclusivity is shown before the choice, never after

A grouped set renders as one box labelled **"one of these"**. The player must be
able to see what a choice forecloses *while deciding*.

Learning the group by watching the other option grey out afterwards is punishing
someone for exploring, and it is the failure that makes an exclusivity system
feel arbitrary instead of tense.

### ▸ RULING 1b — hovering an option previews what it forecloses

**Ruled 2026-08-26.** Hovering any option that would close others **greys those
rows immediately**, in the hard-gate style, with a short line in the warning
colour:

```
  ┌─ one of these ───────────────────────────────────────────┐
  │  A hull lies open across two claims.                     │
  │      SALVAGE RIGHTS                          ← hovered   │
  │  ┄┄ A Verity plate, still transmitting. ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
  │  ┄┄     STILL UNDER WARRANTY            ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄  │
  │         BECOMES UNAVAILABLE                          │
  └──────────────────────────────────────────────────────────┘
```

**The wording is plain on purpose, and it took three tries to get there.**
Earlier drafts said *taking this closes it*, which reads backwards: the line
prints on the row being dimmed but was written from the hovered row's point of
view, so *this* pointed at the wrong thing. Then it was rewritten in the
setting's register — *spoken for, if you do* — which is worse, because **fiction
in a rule slot makes the player parse prose to learn a mechanic.**

> **The fiction lives in the option body and the outcome text. Labels that
> explain a RULE are plain.**

The same correction applies to the aftermath line. It read *the wreck is spoken
for*; it now reads **"Unavailable — Salvage rights taken"**, naming what closed
it rather than making the player infer. Preview and aftermath now share one
word — *unavailable* — in two tenses, so the second confirms the first instead
of teaching a second vocabulary.

The box says a relationship exists **at rest**; the hover says exactly which
rows and how much. Two layers, and the first one does not require the player to
go looking.

**This is the confirmation step**, and it arrives *before* the click rather than
after it — which is why Ruling 3 stands. A dialog after the press asks the same
question twice; a preview before it answers a question the player is already
asking.

**Precedent:** `SectorScreen` already does hover-to-reveal — `card_hovered` →
`_show_readout` opens the keyword panel while a card is held under the cursor.
Same gesture, one layer up. Note also that **nothing in this UI has keyboard or
focus navigation**, so hover-only is consistent rather than exclusionary. If
focus nav is ever added, this fires on focus too.

**Make the restore calm.** Moving the cursor between two rows *inside the same
group* must not flash the greying off and on — **preview state is per-group, not
per-row.** Entering a row updates the preview; only leaving the box clears it.
Found by building it: per-row clear-on-exit flickers on every crossing.

**Reserve the warning line's space at layout time; do not create it on hover.**
A row that grows by a line when hovered shoves every row beneath it down the
panel, and sweeping the cursor across the list makes the whole thing shake. The
line is always in the layout and only its visibility changes. Also found by
building it — see `encounter-prototype.html`, which hit both faults in its first
version.

#### What this unlocks

`ENCOUNTER_REBUILD.md` §4 chose symmetric groups over asymmetric `closes:` lists
for one reason: *the player has to be able to see what a choice forecloses before
making it*, and an asymmetric relationship cannot be drawn as a box.

**Hover preview solves precisely that.** So `closes:` is no longer off the table
— *taking the salvage closes the fight, but taking the fight does not close the
salvage* becomes authorable and legible.

**Groups stay the default.** A box communicates at rest; `closes:` needs a hover
to be understood at all, so it is the escape hatch for relationships a box cannot
express, not the general mechanism.

---

## Beat 3 — reading one

Each row: **label · one line of body · the check badge, if any.**

`SkillCheck.badge()` already produces the right string and needs no change:

```
Sensors 5 · you have 3 · 40%     (one more: 65%)
```

Requirement, current value, odds — all three, always. Its comment is the
argument: *the player is choosing against odds, so the odds are not a surprise to
be sprung*, and the percentage alone would hide which attribute to go and
improve.

### ▸ RULING 2 — one line in the list; full prose only in the detail view

**This closes the open question in `ENCOUNTER_REBUILD.md` §9.**

An option **resolves in place** on the sector screen, *unless* it has **both a
`body` and a `check`** — then it opens the detail view.

- *Strip it now* — no check, no prose. Resolves in the row.
- *Still under warranty* — a transmitting loop, four bands, a Stealth check. Gets
  a screen.

The reason is pacing, not taste. Two to four options across 25–35 systems is a
great deal of reading, and prose that is unavoidable stops being read at all.
Put the atmosphere where the player has chosen to slow down.

`EventScreen` survives as that detail view rather than being deleted.

---

## Beat 4 — you take it

*File a third claim.* `SkillCheck.roll()` fires. Shortfall 2, so 40% CLEAN and
the remainder split evenly — **PARTIAL**, at 30%.

> The board accepts it and one claimant contests it within the hour. You take
> what you can carry and draft a reply you will never send. **+45 credits.**

Outcome text lands where the option row was.

### ▸ RULING 3 — no confirmation step

The odds were printed on the button. **A confirm dialog after showing 40% is
asking the same question twice**, and it teaches the player that the number on
the button was not the commitment.

The hard-gate options (*Pay it — 60 credits*) are the only exception worth
considering, and even there the cost is on the face.

---

## Beat 5 — what changed, and what did not

- `salvage_rights` goes into `MapNode.taken`. The row becomes its outcome text.
- **`still_under_warranty` greys out WITH ITS REASON** — *the wreck is spoken
  for* — never silently.
- **The cordon is untouched.** Independent options are unaffected by a group
  closing, and the player has to be able to see that.
- Nothing else about the system moves.

### ▸ RULING 4 — a claimed option says who claimed it

In co-op the row reads **"taken by [name]"**, not blank and not gone.

`NetSession.claims` is already `{node: {option: peer}}` and host-authoritative,
so this is a label, not a system. An option that silently disappears reads as a
bug; one that says a partner got there first reads as a party.

This is also why `MapNode.taken` is a list of ids rather than a count, and why
`OPTION_SHOP` never shrinks its array: **a taken thing keeps its slot.**

---

## ▸ RULING 9 — an obstacle guards a REWARD, never a door

**Ruled 2026-08-26, and it invalidates a shape both cordons were written in.**

PLOT NEXT JUMP is live from arrival (Beat 6). **So nothing at a system can stand
between the player and anywhere.** Any option whose premise is *you have to get
past me* is lying, and the player finds out the first time they shrug and leave.

Both cordons were written that way and both had to be re-cut:

- *The cordon* — "a picket across the lane… the long way round is eleven hours."
  There is no lane. Leaving is free and instant.
- *Customs cordon* — **one of the six ported events**, and worse. Its own MET
  band pays **nothing**: *"they never look up."* That reads correctly when an
  event IS the whole node and getting past is the only way on. Under the option
  model, declining costs nothing and is strictly better than a 4-in-10 shot at a
  forty-credit fine. **The best outcome was "nothing bad happens."**

**The test, for every option written from here:**

> If the player walks away, what do they not get?
> If the answer is "nothing", the option is a wall and the wall is imaginary.

**The fix in both cases was to put something behind it.** The picket now rings a
debris field with a bulk hauler's spine inside it; the cutter now sits on a
seized hull nine days into processing with a public manifest. Paying buys
access, the check is a break-in, the fight is a break-in by other means, and
declining costs you the hold.

**This is a porting hazard, not just an authoring one.** Every one of the
fourteen events was written for a model where the event was the whole system. Any
of them whose tension came from *being unable to leave* needs re-cutting, not
re-formatting. Check the remaining ported options against the test above before
phase 8.

---

## Beat 6 — leaving

**PLOT NEXT JUMP is live from the moment you arrive**, with every option
untouched.

That is load-bearing. It is what makes a system holding nothing but a fight a
genuine choice rather than a wall — and with sparse coreward doors (phase 5,
parked) it is what stops a bad roll from being a dead end.

---

## The four rulings, together

| | Ruling | Because |
| --- | --- | --- |
| 1 | Groups render as a box before the choice | Punishing exploration makes exclusivity feel arbitrary |
| 1b | Hovering previews what it forecloses | The confirmation belongs before the click, not after |
| 2 | One line in the list; prose in the detail view | Unavoidable prose stops being read |
| 3 | No confirmation step | The odds were on the button |
| 4 | Claimed options name the claimer | A vanishing row reads as a bug |
| 5 | The fight row's detail is a Sensors reward | Resolves spoiler-vs-consistency instead of picking |
| 6 | Rolled order; the box sits in its first member's slot | Sorting a group up implies it matters more |
| 7 | An exhausted system gets its own line | Emptying a system is a subtraction, not a tick |
| 8 | Unaffordable hard gates grey and say by how much | A disabled thing still says what it wants |
| 9 | An obstacle guards a reward, never a door | Leaving is always free, so a wall is imaginary |

---

## What this deletes

- `_quiet_lines()` and its two-element `[line, label]` array
- `_on_action()`'s `match n.type`
- the single `_action` button in `_build_quiet_strip()`
- three of the five parallel `match n.type` sites in `ENCOUNTER_REBUILD.md` §7

**`EventScreen` is NOT deleted** — Ruling 2 gives it a job.

---

## 6. Settled since the first draft

All four of the original open items, ruled 2026-08-26.

### ▸ RULING 5 — the fight row's detail is a Sensors reward

Every other row prints a number; *Break it* printed nothing until the fight
started. Neither fixing that with a flat enemy count nor leaving it bare is
right — one spoils a reveal worth keeping, the other is inconsistent.

**So make it something the player bought.**

```
low sensors    Break it.   Fight.
high sensors   Break it.   Fight · three contacts, one running hot.
```

This is `chart_from()` one scale down. Sensors already marks nodes `sensed`
within a radius — the dish tells you **where** things are; a better dish tells
you **what** they are. It also finally gives SENSORS something to do outside
event checks: its attribute row currently prints an empty effect string because
nothing else reads it.

**This is a new mechanic, not a label.** Scope it into phase 8 deliberately.

### ▸ RULING 6 — rolled order, with the box in its first member's slot

Not the group sorted to the top: **sorting it up implies it matters more, which
is the one thing a group does not mean.**

Rolled order also gives each option a stable position per id, which matters more
than it first appears — with lateral travel and sparse coreward doors the player
passes back through systems, and recognising one by its shape is worth
something.

### ▸ RULING 7 — an exhausted system gets its own line

Every system rolls 2–4 options, so an empty one only ever means **you took it
all**. In a setting whose entire premise is extraction from a universe running
down, that is not a completion tick.

The line should read as a small subtraction rather than an achievement — in the
register of *nothing else here wants anything from you*, which is also simply
true. One line, worth writing properly.

### ▸ RULING 8 — an unaffordable hard gate greys, and says by how much

```
Pay it.   60 credits · you have 40
```

The ladder's rule that *a desperate option is never a disabled button with extra
steps* does not apply here — a hard gate is a meter payment, and 40 credits
genuinely is not 60. What does apply is the honesty underneath it: **a disabled
thing still says what it wants and how far off you are.** Same three-part shape
as `SkillCheck.badge()`.

---

## 7. Still open

- **How much a high Sensors reading reveals** (Ruling 5). Contact count is
  clearly fine. Composition — *one running hot* — starts to read the enemy's
  build, which is closer to a combat preview than a chart reading. Start with
  count and one adjective; measure whether anyone cares before going further.
- **Whether `closes:` ever gets authored** (Ruling 1b). It is now possible.
  Nothing in `batch-02-draft.md` uses it, and that is deliberate — see whether a
  written option actually wants asymmetry before building for it.
