# Encounter prose — handoff

*Generated from the live table on 2026-08-31. **47 encounters.** Every figure in
this document was read out of `OptionTable.all()` rather than counted by hand,
so if it disagrees with the code, the code moved.*

> **Writing NEW encounters?** This file describes what an encounter *is*.
> `ENCOUNTER_COMMISSION.md` is the brief for the eighty being added, and it
> carries the standard, the envelope and the slot list. Read this one first,
> then that one. Run `python tools/encounter_lint.py` before anybody reads a
> word of what you write.

**Who this is for:** an editor working on the words. It describes what an
encounter *is*, what each prose field has to do, where every one of them lives,
and the rules that will fail the build if broken. It deliberately does **not**
reproduce all the prose — that would be a copy going stale from the moment it
was made. Open the file and edit in place; this tells you where to look and what
the constraints are.

---

## 1. Where the words live

| What | File |
|---|---|
| **Encounters — all 47** | `tkg/scripts/systems/OptionTable.gd` |
| System descriptions ("nobody's space, thin salvage") | `MapGen.place_blurb()` |
| Galaxy descriptions, one per kind (17) | `GalaxyGen.KINDS[].blurb` |
| Material flavour text | `tkg/scripts/systems/MaterialTable.gd` |
| Card and module text | `tkg/scripts/autoload/Database.gd` |
| Enemy names and intents | `Database.enemies` |
| Archive documents (in-world found text) | `Database._seed_documents()` |
| The chart primer card | `StarchartScreen.PRIMER_LEGEND` and `_primer_cost()` |

Encounters are the big one and the rest are small. Everything below is about
`OptionTable.gd` unless it says otherwise.

---

## 2. What an encounter is

One dictionary in `OptionTable`'s table. The fields that carry words:

```gdscript
{
    id = &"the_sweep",              # never shown; save-stable, do not rename
    title = "The sweep",            # the plate in the drawer, and the quest name
    body = "...",                   # the setup paragraph, shown when opened
    tags = [&"salvage"],            # colour and word on the plate — see 4
    weight = 8,                     # relative roll chance
    choices = [ ... ],              # what you can do about it
}
```

Each entry in `choices` is one option card:

```gdscript
{
    label = "Cut into it",                    # the button
    check = {attr = &"stealth", need = 4},    # optional skill gate
    met = func():     ...,                    # passed the check
    clean = func():   ...,                    # passed it comfortably
    partial = func(): ...,                    # scraped it
    botched = func(): ...,                    # failed it
}
```

A choice with **no `check`** has a single `effect` instead and always resolves
the same way. A choice **with** a check has up to four outcome bodies, and each
returns a dictionary whose `text` is the prose the player reads:

```gdscript
partial = func() -> Dictionary:
    Run.add_material(&"exotic", 1)
    Run.take_hull_damage(5, "Something feeding on the whale fall took an interest.")
    return {text = "Halfway through the cut the population decides ..."}
```

So each encounter carries **one body** plus **up to four outcome texts per
choice**. That is where the bulk of the words are.

### Payouts are written in rim prices

`OptionTable.purse(base)` and `toll(base)` scale with how deep the system is:
credits by 1.0 / 1.8 / 3.0 / 4.7 / 7.2 across the five tiers, hull by 1.0 / 1.9
/ 3.0 / 4.3 / 5.8. **Author the EASY value.** `purse(30)` is 30 credits on the
rim and 216 at LETHAL.

This exists because thirty-one of the forty-seven encounters span three tiers,
so a literal had to serve danger 3 and danger 8 at once — and measured, it did:
average credits per tier read 50, 50, 49, 52, 56 from EASY to LETHAL before this
landed. **Never quote a credit figure in prose.** Of 207 outcome texts, zero do,
and the ledger rail under the result already prints what moved.

### A walk-away is tagged, and does not spend the encounter

```gdscript
{label = "Leave it counting", stay = true, effect = func() -> Dictionary:
    return {text = "..."}},
```

`stay = true` means declining leaves the thing where it was found: the card
stays live, the result plate reads **LEFT ALONE** rather than RESOLVED, and you
can come back. It is also the only choice that can never be dominated, because
keeping the door open is itself a reason to pick it.

### The hold is the player's

Nothing takes an item the player did not choose. `consume_material_tier` grabs
the first thing of that tier it finds in cargo; it has no callers and must not
get one.

Note the second string in `take_hull_damage` — that is a **death line**. If that
damage kills you it becomes the run's epitaph on the game-over screen, so it has
to read as a cause of death and not as a description of a scratch.

---

## 3. The rule that catches the most mistakes

**An outcome's prose must describe exactly what its code does.** This has been
broken twice and both times the audit caught it, not a playtest:

- `the_glare` paid out modules while its text only described *finding* a wreck.
- `silt` had the same fault hours earlier.

If a branch calls `add_material`, the player has to be told something came
aboard. If it calls `take_hull_damage`, the words have to hurt. If it grants
nothing, the words must not imply a haul. **Read the function body before
rewriting its text**, every time.

---

## 4. Tags

The tag sets the plate's stripe colour and the word printed under the title.
Current spread across 47 encounters:

- **contract** — 18
- **signal** — 11
- **hazard** — 10
- **salvage** — 10
- **fight** — 5
- **quest** — 1

`quest` is not rolled — it is applied to a **placed** encounter, see §6.

---

## 5. Gates: where an encounter can appear

Every gate is optional and they are ANDed. **45 of 47 encounters are gated**;
the rest can appear anywhere.

- `dropped_load` — **max_danger=8** (The dropped load)
- `long_claim` — **max_danger=4** (The long claim)
- `slipping_orbit` — **needs_giant** (Slipping orbit)
- `mine_drift` — **min_danger=5** (Mine drift)
- `corona` — **needs_star=RED HYPERGIANT, min_danger=5** (The corona)
- `the_wind` — **needs_star=BLUE HYPERGIANT, min_danger=5** (The wind)
- `the_glare` — **needs_star=BLUE HYPERGIANT, min_danger=5** (The glare)
- `the_scouring` — **needs_star=BLUE HYPERGIANT, min_danger=5** (The scouring)
- `the_runner` — **min_danger=3, max_danger=8** (The runner)
- `paid_in_full` — **placed** (Paid in full)
- `ghost_signal` — **max_danger=4** (Ghost signal)
- `customs_cordon` — **min_danger=3, max_danger=8** (Customs cordon)
- `the_braid` — **needs_fauna, min_danger=3, max_danger=8** (The braid)
- `refinery_still_lit` — **min_danger=3, max_danger=8** (Refinery, still lit)
- `the_sweep` — **needs_pulsar, min_danger=7** (The sweep)
- `tug_work` — **min_danger=3, max_danger=8** (Tug work)
- `silt` — **needs_fauna, min_danger=3, max_danger=6** (Silt)
- `the_queue` — **min_danger=3, max_danger=8** (The queue)
- `cold_labour` — **min_danger=3, max_danger=8** (Cold labour)
- `quarantine_flag` — **min_danger=3, max_danger=8** (Quarantine flag)
- `counterweight` — **min_danger=5** (Counterweight)
- `the_auction` — **min_danger=5** (The auction)
- `escort` — **min_danger=3, max_danger=8** (Escort)
- `nine_tonnes` — **min_danger=3, max_danger=8** (Nine tonnes of nothing)
- `ice` — **max_danger=4** (Ice)
- `flare_shelter` — **needs_star=RED HYPERGIANT, min_danger=3, max_danger=8** (Flare shelter)
- `deadfall` — **min_danger=5** (Deadfall)
- `the_long_tow` — **min_danger=3, max_danger=8** (The long tow)
- `the_calf` — **needs_fauna, min_danger=3, max_danger=8** (The calf)
- `the_manifest` — **min_danger=9** (The manifest)
- `the_last_berth` — **min_danger=9** (The last counter)
- `counting_backwards` — **min_danger=9** (Counting backwards)
- `holding_pattern` — **min_danger=9** (Holding pattern)
- `the_favour` — **max_danger=6** (The favour)
- `wrong_registry` — **max_danger=6** (Wrong registry)
- `dead_station` — **max_danger=6** (Dead station)
- `distress_beacon` — **max_danger=6** (Distress beacon)
- `whale_fall` — **needs_fauna, min_danger=3, max_danger=8** (Whale fall)
- `inspection_sweep` — **min_danger=3, max_danger=8** (Inspection sweep)
- `derelict_hauler` — **min_danger=2, max_danger=6** (Derelict hauler)
- `cordon` — **min_danger=5** (The cordon)
- `salvage_rights` — **min_danger=2, max_danger=6** (Salvage rights)
- `still_under_warranty` — **max_danger=6** (Still under warranty)
- `collapsed_lane` — **min_danger=3, max_danger=6** (Collapsed lane)
- `drifting_lifepod` — **max_danger=4** (Drifting lifepod)

The full gate list, all ANDed: `min_danger`, `max_danger`, `min_security`,
`max_security`, `min_development`, `max_development`, `regions`, `needs_fauna`,
`needs_star`, `needs_giant`, `needs_pulsar`, **`needs_nebula`** (added
2026-08-31 — every node carried `in_nebula` and no encounter could ask),
`needs_berth`, `berth`, `placed`.

`min_danger` is a depth floor, not a place. Everything else names a physical
fact about the system: a gas giant, a red or blue hypergiant, a neutron star in
reach, a megafauna migration route.

An encounter's gate is a promise its prose has to keep: a `needs_fauna` body may
talk about the herd, a `needs_star` one may talk about the light. An ungated one
may not assume anything about where it is.

---

## 6. Quests (placement)

An outcome can plant an encounter **somewhere else on the map** rather than pay
out here:

```gdscript
return {text = "...", place = &"paid_in_full"}
```

`OptionTable.place(from, id)` picks a target deterministically from the source
system's index, marks it, and the chart draws a **gold square** with the
encounter's `title` next to it. The placed encounter is tagged `quest` and its
title is what the player sees on the map — so **a placed encounter's title is
doing double duty as a map label** and wants to be short and concrete.

Placed encounters carry `placed = true`, which refuses them from the ordinary
roll. They can only arrive by being planted.

The one thread that exists today is `the_runner` → `paid_in_full`. Nobody has
flown it end to end.

---

## 7. Outcomes as the player sees them

A resolved encounter's card is stamped in the centre in large type:

| Code | Stamp |
|---|---|
| `R_SUCCESS` | SUCCESS |
| `R_PARTIAL` | PARTIAL |
| `R_BOTCHED` | BOTCHED |
| `R_DONE` | (spent) |
| `R_GONE` | UNAVAILABLE |

A `stay` choice produces no stamp at all: the plate reads **LEFT ALONE** and the
encounter is still there when you come back.

Options in the same `group` are mutually exclusive — taking one stamps its
siblings UNAVAILABLE. Hovering a card that would close another greys the sibling
and prints **WILL BECOME UNAVAILABLE** across it.

The result drawer shows a **RESULT** panel with the outcome text, a ledger rail
of what moved (credits, fuel, heat, hull), and a **REWARD** slot. Reward
vocabulary is fixed and was chosen deliberately:

- **PRIZE / REWARD** — the moment it is awarded by an encounter
- **JETSAM** — the same object left in the sector to be picked up later
- **SALVAGE** — what a fight leaves

---

## 8. Voice

Read a dozen entries before writing one. The register, consistently:

- **Second person, present tense, plain declaratives.** "You work the seam
  quietly, in the lee of the ribs."
- **Concrete over abstract.** Objects, distances, times. "Eleven seconds."
  "Four years of output." "Two hundred metres in."
- **The universe is indifferent, not hostile.** Things are busy, or old, or
  already dead. Very little is out to get you specifically.
- **Understatement on the worst outcomes.** "The hull holds. Everything on the
  hull does not."
- **No exclamation marks. No rhetorical questions. No winking.**
- **DETAIL IS NOT COMPRESSION**, and this is the one that went wrong most. A
  clause earns its place by parsing on the *first* read. Four lines had to be
  rewritten for it: *"nobody this deep is disinterested twice"*, *"which is how
  you carry that sort of thing"*, *"burning fuel to hold a position you will
  want that fuel back for"*, and a tail that asked the reader to infer a
  negative. If you cannot say the plain version of a clause out loud, cut it.
- **A ship is `it`. People get the pronouns.** "her master is hailing" then "she
  has been holding here" slid between the barge and the pilot with nothing
  marking the handover. `master` went with it — a nautical rank nobody in this
  game speaks. `dockmaster` is fine; it is a job.
- **Credits come from people.** A `contract` pays cash because a client exists.
  A `salvage` or `hazard` with nobody in the body hands over an *object*, and
  the object becomes money at a station.
- Bodies run roughly 40–70 words; outcome texts 20–45. The drawer will wrap
  anything, but a plate that needs scrolling stops being scannable.

### Three quoted in full, as the benchmark

### `dropped_load` — The dropped load

> Two ships sit either side of a drifting cargo pod, running lights on, weapons warm in the unenthusiastic way of crews who would rather be paid than shoot. Both are claiming it on the open channel. The pod is not saying anything — but its transponder log knows whose it is, and your dish is the only disinterested one in range.

- **Read the log [sensors 5] (met/clean/partial/botched)**
- **Snatch it while they argue (effect)**
- **Leave them to it (effect)**

### `the_sweep` — The sweep

> A beam sweeps across this arc every eleven seconds — a pulsar, close, older than anything with a name — and caught inside the sweep is a survey ship that got the interval wrong once. Eleven seconds gets you in. Eleven seconds gets you out. Doing both, carrying cargo, is the question.

- **Time the interval [thermal 7] (met/clean/partial/botched)**
- **Log the bearing (effect)**

### `whale_fall` — Whale fall

> The corpse of something enormous, coming apart slowly in the dark and feeding a whole economy of smaller things while it does. It has been dead long enough to have a population. Most of them are too small to matter and a few of them are not, and all of them are busy.

- **Cut into it [stealth 4] (met/clean/partial/botched)**
- **Take what has come loose (effect)**
- **Let it rest (effect)**


---

## 9. What will fail the build

Run `python tools/encounter_lint.py` first — it finds every fault a machine
can name, and it found 35 rulings and 15 review items on these 47 in one pass.
`--strict` fails only on findings that are NOT in
`tools/encounter_lint_baseline.txt`, so it is usable as a gate today rather than
after a cleanup. Then run `bash .github/scripts/validate.sh` before pushing. Two guards bite prose:

**One word for a company: manufacturer.** The validator greps for retired
vocabulary in both `tkg/scripts` and `docs`, and a hit fails the run. Say
manufacturer — never house, maker, brand, or marque. There are narrow
exemptions (`widowmaker` is a gun, `gatehouse` is a building) but do not lean on
them.

**"Berth" is retired from player-facing text.** Identifiers still use it and are
not to be renamed; the words a player reads must not.

Also worth knowing:

- `id` is save-stable. Renaming one silently breaks saves that reference it.
- `title` appears on the chart for placed encounters (§6).
- `OptionTest` asserts every option has somewhere it could appear. A gate
  combination nothing satisfies fails the suite rather than going quietly dead —
  which is how four encounters were found that had been unreachable for weeks.

---

## 10. The catalogue

All 47, in file order. Line numbers are from
`tkg/scripts/systems/OptionTable.gd` at the time of writing and will drift —
grep the `id` instead.

| id | title | tags | gates | choices | line |
|---|---|---|---|---|---|
| `dropped_load` | The dropped load | contract | max_danger=8 | 3 | 617 |
| `long_claim` | The long claim | contract | max_danger=4 | 3 | 647 |
| `slipping_orbit` | Slipping orbit | hazard | needs_giant | 2 | 680 |
| `mine_drift` | Mine drift | hazard salvage | min_danger=5 | 2 | 709 |
| `corona` | The corona | hazard salvage | needs_star=RED HYPERGIANT, min_danger=5 | 2 | 735 |
| `the_wind` | The wind | hazard | needs_star=BLUE HYPERGIANT, min_danger=5 | 3 | 768 |
| `the_glare` | The glare | hazard | needs_star=BLUE HYPERGIANT, min_danger=5 | 3 | 800 |
| `the_scouring` | The scouring | hazard salvage | needs_star=BLUE HYPERGIANT, min_danger=5 | 3 | 827 |
| `the_runner` | The runner | contract | min_danger=3, max_danger=8 | 3 | 856 |
| `paid_in_full` | Paid in full | quest | placed | 2 | 890 |
| `ghost_signal` | Ghost signal | signal | max_danger=4 | 2 | 910 |
| `customs_cordon` | Customs cordon | signal fight | min_danger=3, max_danger=8 | 2 | 937 |
| `the_braid` | The braid | signal | needs_fauna, min_danger=3, max_danger=8 | 3 | 966 |
| `refinery_still_lit` | Refinery, still lit | contract | min_danger=3, max_danger=8 | 3 | 997 |
| `the_sweep` | The sweep | hazard | needs_pulsar, min_danger=7 | 2 | 1031 |
| `tug_work` | Tug work | contract | min_danger=3, max_danger=8 | 3 | 1060 |
| `silt` | Silt | hazard | needs_fauna, min_danger=3, max_danger=6 | 3 | 1094 |
| `the_queue` | The queue | contract | min_danger=3, max_danger=8 | 3 | 1125 |
| `cold_labour` | Cold labour | contract | min_danger=3, max_danger=8 | 3 | 1147 |
| `quarantine_flag` | Quarantine flag | signal | min_danger=3, max_danger=8 | 2 | 1180 |
| `counterweight` | Counterweight | contract | min_danger=5 | 3 | 1208 |
| `the_auction` | The auction | contract | min_danger=5 | 3 | 1240 |
| `escort` | Escort | fight contract | min_danger=3, max_danger=8 | 3 | 1270 |
| `nine_tonnes` | Nine tonnes of nothing | contract | min_danger=3, max_danger=8 | 3 | 1291 |
| `ice` | Ice | contract | max_danger=4 | 3 | 1322 |
| `flare_shelter` | Flare shelter | hazard | needs_star=RED HYPERGIANT, min_danger=3, max_danger=8 | 3 | 1355 |
| `deadfall` | Deadfall | salvage | min_danger=5 | 3 | 1388 |
| `the_long_tow` | The long tow | contract | min_danger=3, max_danger=8 | 3 | 1417 |
| `the_calf` | The calf | signal | needs_fauna, min_danger=3, max_danger=8 | 3 | 1451 |
| `the_manifest` | The manifest | contract | min_danger=9 | 3 | 1483 |
| `the_last_berth` | The last counter | contract | min_danger=9 | 3 | 1514 |
| `counting_backwards` | Counting backwards | signal | min_danger=9 | 3 | 1536 |
| `holding_pattern` | Holding pattern | signal | min_danger=9 | 3 | 1581 |
| `the_favour` | The favour | contract | max_danger=6 | 3 | 1611 |
| `wrong_registry` | Wrong registry | signal | max_danger=6 | 3 | 1632 |
| `dead_station` | Dead station | salvage | max_danger=6 | 2 | 1660 |
| `distress_beacon` | Distress beacon | signal fight | max_danger=6 | 3 | 1676 |
| `whale_fall` | Whale fall | salvage | needs_fauna, min_danger=3, max_danger=8 | 3 | 1705 |
| `inspection_sweep` | Inspection sweep | contract | min_danger=3, max_danger=8 | 3 | 1737 |
| `derelict_hauler` | Derelict hauler | salvage | min_danger=2, max_danger=6 | 2 | 1774 |
| `hostile_contact` | Hostile contact | fight | — | 2 | 1792 |
| `dead_hull` | A dead hull | salvage | — | 2 | 1821 |
| `cordon` | The cordon | fight signal | min_danger=5 | 3 | 1845 |
| `salvage_rights` | Salvage rights | salvage contract | min_danger=2, max_danger=6 | 3 | 1876 |
| `still_under_warranty` | Still under warranty | salvage | max_danger=6 | 2 | 1906 |
| `collapsed_lane` | Collapsed lane | hazard | min_danger=3, max_danger=6 | 2 | 1934 |
| `drifting_lifepod` | Drifting lifepod | signal | max_danger=4 | 2 | 1966 |

---

## 11. Regenerating this document

The catalogue above was read out of the live table, not typed:

```
godot --headless --path tkg -- encdump
```

That prints every encounter with its id, title, tags, gates, body and choices.
If encounters are added or gates change, re-run it rather than editing §10 by
hand — a hand-maintained catalogue of 47 things is a catalogue that is wrong.
