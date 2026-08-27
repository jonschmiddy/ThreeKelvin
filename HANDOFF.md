# Handoff — writing options for Three Kelvin

**For a chat session with no repo access.** Everything needed to write a valid
option is in this file. Checked against `main` on 2026-08-27, after phase 8b —
not against the older briefs, which are wrong in three places noted below.

Paste finished options back into the repo session and they go into
`OptionTable.gd` as-is.

---

## What an option is

A system in Three Kelvin rolls **2–4 options** on arrival. Each one is a
*situation* with **two or three things you can do about it**. The chart never
says what a system holds — you find out by flying there.

The arrival screen renders them as a list. One line of prose per option, the
label on a button, and the odds on its face.

```gdscript
{
	id = &"salvage_rights",           # stable identity, NEVER the title
	title = "Salvage rights",
	body = "A hull lies open across two claims and neither claimant is here...",
	tags = [&"salvage", &"contract"],
	group = &"wreck",                 # &"" is independent
	weight = 11,
	regions = [MapGen.Region.LAWLESS], min_danger = 2,
	choices = [ ... ],
}
```

**The `id` is the key and the title is copy.** Renaming a title is free;
renaming an id invalidates every save that rolled it.

---

## The one test every option must pass

> **If the player walks away, what do they not get?**
> If the answer is "nothing", the option is a wall — and the wall is imaginary.

PLOT NEXT JUMP is live from the moment you arrive. **Nothing at a system can
stand between the player and anywhere else.** Any option whose premise is *you
have to get past me* is lying, and the player finds out the first time they
shrug and leave.

This killed two already-written options. An obstacle has to **guard a reward**,
never a door. A picket across a lane is nothing; a picket ringing a debris field
with a bulk hauler's spine inside it is an option.

---

## Choices

Two shapes. Both legal, mix freely inside one option.

**Flat** — no roll:

```gdscript
{label = "Strip it now", effect = func() -> Dictionary:
	return {text = "You take what is loose and leave.", module = true}},
```

**Checked** — rolls an attribute, four possible bands:

```gdscript
{label = "File a third claim",
	check = {attr = &"sensors", need = 5},
	met = func() -> Dictionary:      # you meet or exceed `need` — no roll at all
		Run.add_credits(35)
		return {text = "Your filing is cleaner than either of theirs."},
	clean = func() -> Dictionary:    # rolled and won
		return {text = "Your claim holds long enough to matter."},
	partial = func() -> Dictionary:  # rolled and half-won
		Run.add_credits(45)
		return {text = "The board accepts it and one claimant contests it."},
	botched = func() -> Dictionary:  # rolled and lost
		Run.add_credits(-25)
		return {text = "You file into the middle of a dispute."}},
```

Bands fall back down the ladder, so **a check with only `met` and `botched` is
complete and legal.** Write the bands you care about.

### The six attributes

`&"hull"` · `&"thrust"` · `&"maneuver"` · `&"thermal"` · `&"sensors"` ·
`&"stealth"`

### The odds ladder — this is the whole tension

| Short by | Chance of the good outcome |
| --- | --- |
| 0 (you meet it) | **certain, no roll** |
| 1 | 65% |
| 2 | 40% |
| 3 | 20% |
| 4 or more | 5% |

Meeting a requirement is **certain** — an attribute you earned should never fail
you. Being one short is a real attempt; being four short is a stunt, and the 5%
floor exists so a desperate option is never a disabled button with extra steps.

Failure splits **evenly** between PARTIAL and BOTCHED. At four short that is
47.5% each — so **PARTIAL is the band a marginal attempt produces most often,
and it is where the design effort goes.** It must not read as a watered-down
botch. Give it its own outcome, not a smaller number.

### Hard gates

```gdscript
{label = "Pay it", cost_credits = 60, effect = func() -> Dictionary: ... },
```

Only for **meter payments and physical impossibility**. Everything else rolls
the ladder. The button greys when you cannot afford it and says by how much —
*60 credits · you have 40* — so a disabled thing still states what it wants.

### Fights

```gdscript
{label = "Engage", fight = true, effect = func() -> Dictionary:
	return {text = "It came out here expecting easier work.", fight = true}},
```

**`fight` appears twice and it is not a typo.** On the *choice* it is a
declaration — *this row leads to a fight* — which the list reads before the
click, to print what your sensors can tell you about it. In the *returned
dictionary* it is the trigger that actually starts the fight. An outcome may
open a fight the choice never declared; that is a twist, and it is why they are
separate.

---

## What an option may pay

**Only these. An option that pays in a mechanic nobody built cannot land.**

| Reward | How | Note |
| --- | --- | --- |
| credits | `Run.add_credits(n)` | negative to charge |
| fuel | `Run.fuel += n` / `Run.fuel = maxi(0, Run.fuel - n)` | |
| **a module** | `return {module = true}` | **not a function call** — see below |
| materials | `Run.add_material(&"exotic", n)` | **only `exotic` and `relic` exist** |
| hull damage | `Run.take_hull_damage(n, "reason")` | |
| healing | `Run.heal(n)` | |

**The module is the exception and the briefs get it wrong.** Older documents say
`Run.stow(LootGen.roll_module(danger))`. Do not write that. Return
`{module = true}` and the caller rolls one at the system's own danger — that is
how rarity stays tied to where you are.

**Standing is out.** It exists as a dictionary but nothing subtracts from it,
nothing displays it, and it only affects the sell price. A consequence the
player cannot see is not a consequence. No option touches it.

**Archive documents cannot be granted.** A system either holds one or it does
not — it is derived from the system's position. An option can only recover the
one that is already here.

### Three rules on failure

- **Failure domain.** A ram costs hull, a sneak costs detection, a burn costs
  heat. **Botches surprise in degree, never in kind.** A stealth botch must not
  cost hull.
- **Pile-on guard.** No BOTCHED band stacks two of {hull damage, malfunction,
  combat entry}.
- **Every group needs a free exit.** Not every option — declining an independent
  option is already free. But if every member of a boxed exclusive set costs
  something, the box needs a *leave it* row.

---

## Groups — exclusivity

`group = &"wreck"` on two or more options makes them **mutually exclusive**:
taking one closes the rest. The screen boxes them under **ONE OF THESE**, and
hovering a member greys its siblings *before* the click.

**A group means "these compete for the same thing", not "these matter more."**
They stay in rolled order and are never sorted to the top.

Group whole *situations*, not individual lines — `salvage_rights` competes with
`still_under_warranty` because they are two readings of the same wreck.

---

## Where an option can appear

All gates are **ANDed**. Omit them for an option that can happen anywhere —
`hostile_contact` and `dead_hull` are ungated on purpose, because a hostile and
a dead hull are the two things that can happen in any system.

| Field | Meaning |
| --- | --- |
| `min_danger` / `max_danger` | 1–10ish, rises toward the core |
| `min_security` / `max_security` | how policed |
| `min_development` | `MapGen.Development.` `UNCLAIMED` `OUTPOST` `SETTLEMENT` `CITY` `CAPITAL` |
| `regions` | `MapGen.Region.` `FRONTIER` `TERRITORY` `COSMOPOLITAN` `LAWLESS` `FAUNA` `CORE` |
| `needs_fauna = true` | the system has living things in it |
| `needs_berth = true` | any manufacturer has a berth here |
| `berth = &"verity"` | that specific manufacturer has one |

**Gate lightly.** A heavily gated option is one most players never see. The
current table over-gates: at the outer rim almost nothing qualifies, which is why
a scaffolding rule has to force a fight or salvage option into thin systems.

---

## Tags

`&"fight"` · `&"salvage"` · `&"signal"` · `&"contract"`

Not decoration — the game reads them:

- **`fight`** — contracts hunt for a system offering one, and fights are where
  modules and rarity come from.
- **`salvage`** — **the Hellbender eats systems tagged this.** It is currently
  eating twice as much as it was designed to, precisely because this tag became
  common. Do not tag salvage reflexively.

---

## Weight

Relative likelihood within whatever the gates admit. Current spread: **16**
(`hostile_contact`, the most common thing in space) down to **6**
(`still_under_warranty`, a specific manufacturer's specific paperwork).

**10 is ordinary.** Rare and flavourful gets 6; the plain thing that happens
everywhere gets 14–16.

---

## Prose

Roughly what is already there, which is worth matching:

- **Body: 1–3 sentences.** Only the first sentence shows in the list — the rest
  appears if the option opens a detail view. Front-load it.
- **Outcome text: one or two sentences.** Written as fiction, and deliberately
  never says "you failed" — the band is labelled separately above it.
- **Labels are plain and imperative.** *Strip it now. Break it. Answer the
  notice.* Anything explaining a **rule** is plain English, never in-fiction —
  making a player parse prose to learn a mechanic is the failure mode.
- **The register.** Dry, procedural, faintly bureaucratic; the universe is
  running down and everyone is filing paperwork about it. Nothing is heroic.
  Humour is deadpan and comes from institutions, not jokes.

An option gets its own screen only if it has **both a body and a check**.
Everything else resolves in its row. Two to four options across twenty-five
systems is a lot of reading, and prose that is unavoidable stops being read.

---

## Already written — do not duplicate

| id | tags | group | weight | gates |
| --- | --- | --- | --- | --- |
| `hostile_contact` | fight | — | 16 | none |
| `dead_hull` | salvage | — | 14 | none |
| `cordon` | fight, signal | — | 12 | LAWLESS, sec ≤2, danger ≥3 |
| `salvage_rights` | salvage, contract | wreck | 11 | LAWLESS/TERRITORY, danger ≥2 |
| `still_under_warranty` | salvage | wreck | 6 | 3 regions, Verity berth |
| `collapsed_lane` | signal | — | 9 | 3 regions, dev ≥ SETTLEMENT |
| `drifting_lifepod` | signal | — | 10 | none |

**Seven options is the whole table**, and a system draws about three of them.
That is the problem this content session exists to fix.

### What is most wanted

1. **Ungated or lightly gated options.** The rim currently has almost nothing
   legal, which is what the scaffolding rule is papering over. Options that can
   happen *anywhere* are worth more right now than perfectly-gated ones.
2. **Non-salvage rewards.** The table leans on wrecks, which is feeding the
   Hellbender. Signals, claims and contracts paying credits, fuel and materials
   are underweight.
3. **More exclusive groups.** Only one exists (`wreck`). Exclusivity is the point
   of the whole system and there is exactly one instance of it in the game.
4. **`FAUNA` and `CORE` region options.** Nothing is written for either.

---

## Format to hand back

Either GDScript matching the shape above, or plain prose in this order — the
repo session can convert it:

```
id, title
body (1-3 sentences)
tags, group, weight, gates
for each choice:
  label
  check (attribute + number) or cost, or neither
  the outcome for each band you want to write, with what it pays
```

**A finished option is one that answers the walk-away test, pays only in what
exists, and gives PARTIAL something real to say.**
