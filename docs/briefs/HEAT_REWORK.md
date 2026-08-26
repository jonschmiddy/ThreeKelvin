# Heat rework — dissipation stops being a drip

*Design brief, 2026-08-25. Written offline against `main` as merged (SaveGame VERSION 13,
PROTOCOL 8 at time of writing; **now 14 / 8** — see `ROADMAP.md` §1). Line numbers will move; grep the quoted strings.*

**Two changes, ruled 2026-08-25:**

1. **Delete per-turn dissipation in combat.** A vent card sheds
   `vent + dissipation()` instead.
2. **Raise `cool_in_transit()` from half rate to full rate.**

Sibling documents: `ENCOUNTER_REBUILD.md` (§6 makes signature the map's only
involuntary risk), `GALAXY_SCALE.md`. §6 below depends on both.

---

## 1. The complaint, and what the numbers say about it

*Per-turn dissipation in combat does not feel good.*

It is one point.

| | heat_cap | dissipation |
| --- | --- | --- |
| light | 8 | **2** |
| medium | 12 | **1** |
| heavy | 18 | **1** |

Card heat runs 1 to 6, mostly 1–4, and a turn plays two or three cards. So the
shed is one point against a gain of four or more.

**It is too small to plan around and too present to ignore.** Every turn it
prints `Dissipated N heat.`, nudges the gauge, and asks the player to redo
arithmetic for a change that never alters a decision.

**The stat lies about its own importance.** `attr_thermal()` is
`(heat_cap - THERMAL_FLOOR) / 2.0 + dissipation / 2.0` — dissipation is *half
the attribute*. A module granting `+1 dissipation` reads as a real thermal
upgrade and delivers one heat a turn. The HUD tooltip in `HudBar.gd`:302-306
prints *Vents %d a turn on its own* in a gauge the player watches constantly,
which is a lot of prominence for one point.

**And it is why the interesting half of heat was never built.** `heat_scale`
appears on **one** card of 149. `damage_equals_heat`, one. `brace_from_heat`,
one. Those cards want heat high; automatic cooling works against them every
turn, in a direction the player cannot switch off. The run-hot archetype does
not exist because the base rules fight it — nineteen cards print heat, fifteen
vent it, three spend it.

---

## 2. Change one: dissipation amplifies venting

### Do

**Remove** the end-of-turn shed block in `Combat.gd` (~:392-395):

```gdscript
var shed := mini(Run.heat, Run.dissipation())
if shed > 0:
    Run.heat -= shed
    _log("Dissipated %d heat." % shed, &"sys")
```

**Change** `CardResolver.gd`:113-117 so a vent card sheds `c.vent + Run.dissipation()`:

```gdscript
if c.vent > 0:
    var v := mini(Run.heat, c.vent + Run.dissipation())
    Run.heat -= v
    if v > 0:
        cb._log("Vented %d heat." % v, &"heat")
```

`vent_all` (`CardResolver.gd`:38-43) is unaffected — it already zeroes heat, and
there is nothing for a multiplier to add to. Two cards use it.

### Why this and not "make dissipation bigger"

Raising the numbers would turn heat into a second energy bar: both refreshing
every turn, both capping what a turn can do, when the game already has energy for
that job. Heat is supposed to accumulate and force a reckoning.

What this version buys:

- **Dissipation becomes a multiplier on a decision instead of a drip that
  happens to you.** The stat's prominence is finally earned.
- **Fifteen vent cards get better** and become real deck picks rather than
  competing against free automatic cooling. On a Calyx hull with
  `dissipation = 1` plus baffled vents, Bleed Heat goes from 3 to 5.
- **Heat accumulates honestly**, so `heat_scale` and `damage_equals_heat` can
  sustain themselves and the run-hot archetype has room to be authored. That
  content is out of scope here but this is the change that unblocks it.
- **The fiction lands.** In a fight you generate faster than any radiator sheds,
  so heat comes off only when you deliberately dump it. Between systems you
  drift with nothing else to do, and that is exactly what §3 is.

### The end-of-turn order matters

Current sequence in `end_turn()`: stuck `hand_heat` → brace maintenance (+1) →
shed → overheat check. **Removing the shed moves the overheat check one step
closer to the heat you just generated**, which is the intended effect — the burn
now measures what you actually did rather than what survived a free refund.

Do not compensate by softening overheat. It is deliberately a linear 1:1 hull
burn with no cliff and no cap, and Solari's 5-set halving it is a set bonus that
should stay meaningful.

---

## 3. Change two: full-rate transit cooling

### Do

`RunState.cool_in_transit()`:

```gdscript
func cool_in_transit() -> void:
    heat = maxi(0, heat - maxi(1, dissipation()))
```

### Why the old measurement does not apply

The existing comment records full rate being tried and rejected: average
signature on arrival fell from 0.32 to 0.05 over a thousand runs, which *deleted*
the map mechanic rather than making heat manageable between systems.

**That test ran with in-combat dissipation still active.** Fights ended much
cooler than they will after §2, so full-rate transit cooling was compounding an
already-cool starting point. With combat cooling gone, fights end near cap and
full-rate transit becomes the counterweight rather than a second one.

**⚠ SUPERSEDED — see `ROADMAP.md` §6.** Full-rate transit cooling was tried in
phase 2 and **reverted**: it made the heat curve worse, not better. And this
section's target was wrong by an order of magnitude — it aims at *"roughly the
old 0.32"* when the measured figure was **0.04**. The half that landed is §2,
dissipation-amplifies-venting, and it worked: post-fight signature 0.14 → 0.32,
"left a fight hot" 19.1% → 34.9%. **Do not re-open this.**

*Original text follows, kept for the record.* The target is roughly
the old 0.32 average arrival signature. If it overshoots, the dial is the rate,
not the floor — the floor of 1 exists so the worst dissipation in the game still
cools eventually instead of fossilising at capacity, and it should stay.

---

## 4. Everything that has to move with it

The shed and the tooltip are not the only places that describe this rule.

**Note on the word "pip".** It means two different things in this codebase: the
heat indicator printed on a card face (`CardData.net_heat()`) and a step on the
1-10 attribute ladder (the `effect` strings in `RunState`'s attribute rows).
Both appear below and they are unrelated. Worth disambiguating one day; not in
this pass.

| File | Line | What |
| --- | --- | --- |
| `Combat.gd` | ~392-395 | delete the shed block |
| `CardResolver.gd` | 113-117 | vent gains `+ Run.dissipation()` |
| `RunState.cool_in_transit()` | ~863 | half rate → full, and rewrite the comment; keep the record of what was tried |
| `HudBar.gd` | 302-306 | **player-facing and now false.** Both branches print *Vents %d a turn on its own.* Replace with what dissipation now does — how much a vent card is worth |
| `SectorScreen.gd` | 913-914 | the card preview prints `-%d HEAT` as `mini(c.vent, Run.heat)`. Must become `mini(c.vent + Run.dissipation(), Run.heat)` or the preview lies about the card in the player's hand |
| `RunState.gd` | 1354 | **player-facing and now false.** The THERMAL attribute row's help reads *A pip is 1 more heat capacity and 1 more heat vented every turn.* The second half must become what dissipation now buys — 1 more heat per vent card played. The sentence gets more honest, not less: today the dissipation half sounds significant and is worth one point a turn |
| `CardData.net_heat()` | ~218 | returns `heat - vent` for the card pip. **Decide (§5).** |
| `Policy.gd` | 86 | the sim's vent threshold — *most of the difference between the two policies*, per its own comment. Retune, do not just leave it |
| `CoFightTest.gd` | 547 | same threshold, hardcoded separately |
| `HullData.gd`:47, `ModuleData.gd`:58 | | the field docstrings describe a per-turn shed |
| `Widgets.gd` | 174 | hull comparison row for dissipation — check the label still reads true |

**`SectorScreen.gd`:913 is the one to not miss.** It is the preview a player
reads before committing a card, and after §2 it under-reports every vent card by
the ship's whole dissipation.

---

## 5. Where the number is displayed — RULED

A vent card's value is now part card and part ship. **Display each half where it
lives.** Three surfaces, three jobs:

| Surface | Shows | Why |
| --- | --- | --- |
| Card face pip (`CardData.net_heat()`) | the base, `heat - vent`. **Unchanged.** | Not because a dynamic face would be wrong — see the note below — but because the value it would add **never changes during a fight**. `dissipation()` is hull + perk + installed modules, and you cannot refit mid-combat. A constant that holds for a whole run is learned once from the gauge, not reprinted on every card |
| Heat gauge hover (`HudBar.gd`:302-306) | what **your ship** adds — "vent cards shed %d more" | Learned once, applies to every vent card you own. This string is on the fix list anyway; it currently claims a per-turn shed |
| Play preview (`SectorScreen.gd`:913) | the exact total for **this play** | A preview at the moment of commitment should be precise |

This is why `net_heat()` needs no change at all. The ship's half was never the
card's to print.

**On dynamic card faces generally.** An earlier draft justified the static pip
by citing the `AffixData` ruling — *a card whose face changes with the module
that granted it is a card nobody can learn*. **That was a misapplication.** That
ruling is about affixes mutating individual card fields, so two copies of the
same card in one deck read differently depending on which module granted each.
A ship-wide dissipation bonus is not that: every vent card shifts by the same
amount and no two copies disagree.

Dynamic card faces are a normal, well-precedented thing — Slay the Spire prints
0 on cards Corruption has made free and rewrites damage numbers as Strength
changes. The distinction is that **those modifiers move during play** and this
one does not.

**The condition for revisiting:** if anything is ever added that changes
`dissipation()` mid-fight — a card, a status, an enemy effect — the pip should
go dynamic at that point, and the argument above is the reason why.

**Outside combat**, the heat gauge is not the surface in front of you — you
evaluate cards on the ship screen, where the THERMAL attribute row is. So
`RunState.gd`:1354 carries the same fact in that context.

**Both strings must read `Run.dissipation()`, not a literal.** Two hardcoded
copies of one quantity is precisely the failure `DOC_RECONCILIATION.md` exists
to clean up, and this codebase has the receipts.

---

## 6. Interactions

**Ambush is about to be the map's only involuntary content.**
`ENCOUNTER_REBUILD.md` §6 makes signature the entire map-layer risk dial. §2 and
§3 both move signature hard and in opposite directions — fights end hotter,
transit cools more. Land these two **before** tuning ambush odds, or the
tuning is done against a signature curve that is about to change.

**Order against the encounter and galaxy work.** This is independent of both and
touches no file they touch except `RunState`. It can land any time. Cleanest is
**before** the encounter rebuild, so ambush is tuned once against the new
signature curve rather than twice.

**No version bumps.** Nothing here changes a serialised key, a wire key, or a
generated shape. `heat` and `dissipation` already save. `version_guard.py`
should stay quiet — if it fires, something changed that this brief did not
intend.

---

## 7. Measuring it

Both changes move the combat economy and the map risk curve. Take a baseline
first if one is not already banked from the galaxy work:

```bash
godot --headless --path tkg -- sim runs=500
```

Then after, watching four things:

1. **Average arrival signature** — target roughly the old 0.32. This is the
   number that says whether §3 landed.
2. **Win rate**, against the high-win-rate target in `ENCOUNTER_REBUILD.md` §8.
   Expect it to fall somewhat: heat is now harder to shed in a fight.
3. **Overheat frequency and total hull burned.** If burn spikes, the vent
   multiplier is not carrying enough and the answer is more vent cards in the
   pool, not restoring the drip.
4. **The two sim policies diverging correctly.** `Policy.gd`:86 is the single
   threshold separating hot from cold play; if both policies now behave the
   same, the threshold needs retuning before any other number here is
   trustworthy.

Also worth a manual look: a light hull (`heat_cap` 8, `dissipation` 2) has the
smallest tank and the best multiplier, and a heavy (18/1) the opposite. That
gap widens under §2 and may want a balance pass of its own.
