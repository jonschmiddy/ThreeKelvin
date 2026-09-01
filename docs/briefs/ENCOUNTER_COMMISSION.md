# Eighty encounters — commission

*Written 2026-08-31 for a session that will write them. Every number below was
measured off the live table, not estimated; the slot list in §3 is derived from
where the coverage actually thins out. The table is at 47 today and this takes
it to 127.*

**Deliverable:** eighty new entries in `tkg/scripts/systems/OptionTable.gd`,
written to the standard in §2, filling the slots in §3, passing
`python tools/encounter_lint.py --strict` and `-- optiontest`.

---

## 1. Read these three first

| | |
|---|---|
| `docs/briefs/ENCOUNTER_PROSE.md` | what an encounter *is* — fields, outcomes, the file map |
| `tools/encounter_lint.py` | every rule a machine can check. Run it. It is faster than a review |
| `counting_backwards`, `the_manifest`, `the_last_counter`, `holding_pattern` | the four written to standard. Read all four before writing one |

Those four are in `OptionTable.gd` and are the benchmark. Everything below is
the shorthand for what they do.

---

## 2. The standard

### The prose

- **Second person, present tense, plain declaratives.** "You work the seam
  quietly, in the lee of the ribs."
- **Plain but detailed.** Detail carries the mood; vocabulary does not. Forty-one
  years. Four days. Eleven hundred units against a receipt for nine. A second
  stamp for the copy nobody collects. No word a tired pilot would not say — no
  *picket*, no *sundries*, no *carcass*.
- **DETAIL IS NOT COMPRESSION.** This is the one that went wrong most. A clause
  earns its place by parsing on the *first* read. Squeezing a plain sentence
  until it sounds clever buys nothing and costs a second pass, and the second
  pass is where a player stops reading encounters at all. Four lines had to be
  rewritten for this: *"nobody this deep is disinterested twice"*, *"which is
  how you carry that sort of thing"*, *"burning fuel to hold a position you will
  want that fuel back for"*, and a tail that asked the reader to infer a
  negative. If you cannot say the plain version of a clause out loud, cut it.
- **The universe is indifferent, not hostile.** Things are busy, or old, or
  already dead. Very little is out to get you specifically.
- **Understatement on the worst outcomes.** "The hull holds. Everything on the
  hull does not."
- **THE PLAYER NEVER LEAVES THE SHIP.** No arms, hands, boarding on foot,
  corridors, lamplight. The ship has a grapple, a cutter, a dish and a board.
- **A ship is `it`. People get the pronouns.** "her master is hailing" then "she
  has been holding here" slid between the barge and the pilot with nothing
  marking the handover. `master` is retired with it — a nautical rank nobody in
  this game speaks. `dockmaster` is fine, it is a job.
- **No exclamation marks, no rhetorical questions, no winking.**
- **Length:** bodies **400–580 characters**. The four run 402–573. Outcome texts
  run 120–420. Anything under 300 reads as a stub.

### The decision

- **No dominated choice.** If one option costs nothing and gives nothing while
  another costs nothing and gives something, the first is decoration. **Twenty-two
  of the current forty-seven have this fault** — do not add more.
- **Three choices, three *kinds* of question.** A check you might fail is not the
  same question as a resource you must spend, which is not the same as a thing
  you decline. `the_last_counter` has no check at all and is still a decision:
  one choice hands you forty fuel, another spends eight.
- **Tag every walk-away `stay = true`.** Declining must not spend the encounter.
  A tagged walk-away is also the only choice that can never be dominated — it
  keeps the door open, which is a reason to pick it.
- **Never reach into the hold.** `consume_material_tier` takes the first item of
  that tier it finds and the player never picks which. It has one caller left in
  the codebase and that caller is wrong. The hold is the player's.

### The money

- **Credits come from people. Deep space pays in cargo.** A `contract` pays cash
  because a client exists. A `salvage` or `hazard` with nobody in the body hands
  over an *object*, and the object becomes money at a station where somebody is
  standing behind a counter. **Seven encounters currently pay cash to an empty
  sky.**
- **Never quote a credit figure in prose.** Of 207 outcome texts, zero do, and
  the ledger rail under the result already prints what moved. Payouts scale with
  depth; a quoted figure would be wrong at four tiers out of five.
- **Write rim prices.** `OptionTable.purse(30)` is 30 credits at EASY and 216 at
  LETHAL. `toll(4)` is 4 hull at EASY and 23 at LETHAL. Author the EASY value.
- **Named for the story, rolled for the scale.** `material_id = &"survey_film"`
  has a **fixed** value and is the one payout the tier ladder cannot reach —
  alone it made a LETHAL branch pay 35, less than an EASY success. Pair a named
  item with `material = &"wreck"`, which grades with danger.

### The envelope

| tier | danger | check | credits | hull cost | `purse` base | `toll` base |
|---|---|---|---|---|---|---|
| EASY | 1–2 | 3–4 | 20–40 | 2–6 | 20–40 | 2–6 |
| ROUGH | 3–4 | 4–5 | 40–70 | 5–10 | 22–39 | 3–5 |
| HARD | 5–6 | 5–6 | 70–110 | 9–15 | 23–37 | 3–5 |
| BRUTAL | 7–8 | 6–7 | 110–170 | 14–20 | 23–36 | 3–4 |
| LETHAL | 9–10 | 7–8 | 170–260 | 18–28 | 24–36 | 3–4 |

The base columns are what you actually type. They barely move — the tier does
the work.

---

## 3. The eighty slots

Derived from the measured gaps. Current pools:

```
          total  free   fight hazard salvage signal contract
EASY        16    12      2     1      5      4      5
ROUGH       33    17      4     4      6      8     14
HARD        38    16      5     9     10      7     14
BRUTAL      30    11      4     8      6      5     12
LETHAL      18     5      2     7      5      3      4

sky gates:  RED 2 · BLUE 3 · gas giant 1 · pulsar 1 · fauna 4 · nebula 0
```

### 3a. The sky — 30

The thinnest thing in the game. A red hypergiant has **two** encounters; a blue
has three; a nebula has none at all because the gate did not exist until today.

| gate | new | tiers to spread across | notes |
|---|---|---|---|
| `needs_star = MapGen.Star.RED` | 6 | 2 ROUGH, 2 HARD, 2 BRUTAL | a huge cool star: flares, shelter, things that live in the light |
| `needs_star = MapGen.Star.BLUE` | 6 | 2 HARD, 2 BRUTAL, 2 LETHAL | hard radiation, ablation, a sky that erases things |
| `needs_giant = true` | 5 | 1 EASY, 2 ROUGH, 2 HARD | atmosphere, moons, scooping, pressure |
| `needs_pulsar = true` | 5 | 1 HARD, 2 BRUTAL, 2 LETHAL | the beam, its interval, what it leaves |
| `needs_nebula = true` | 5 | 2 EASY, 2 ROUGH, 1 HARD | **new gate.** Gas you cannot see through. Hiding, losing things, being lost |
| `needs_fauna = true` | 3 | 1 ROUGH, 1 HARD, 1 BRUTAL | herds, migration, what a body is worth |

### 3b. Depth — 30

Weighted to where the ungated pool is thinnest. **Ungated by physics** — no
`needs_*`, no `regions` — because a deep ordinary system currently draws from a
bag of five.

| tier | new | band lines |
|---|---|---|
| LETHAL | 8 | `min_danger = 9` |
| BRUTAL | 7 | `min_danger = 7, max_danger = 8` |
| EASY | 8 | `max_danger = 4` (EASY–ROUGH) |
| HARD | 4 | `min_danger = 5, max_danger = 6` |
| ROUGH | 3 | `min_danger = 3, max_danger = 6` |

### 3c. Tags — 20

`fight` is 2–5 per tier and is the tag that should feel most present.

| tag | new | tiers | notes |
|---|---|---|---|
| `fight` | 12 | 2 EASY, 3 ROUGH, 3 HARD, 2 BRUTAL, 2 LETHAL | something that shoots. `fight = true` in an outcome starts it |
| `hazard` | 8 | 4 EASY, 4 ROUGH | EASY has **one** hazard. The rim should still be able to hurt you |

**Total: 30 + 30 + 20 = 80.** A slot may satisfy one line only — do not count
a red-star fight against both 3a and 3c.

---

## 4. Format

Append to the `_build()` table in `OptionTable.gd`, same shape as everything
already there:

```gdscript
{
    id = &"unique_snake_case",       # save-stable, never shown, never renamed
    title = "Three words or so",     # shown on the plate; ALSO the chart label
                                     # if the encounter is ever placed
    body = "400-580 characters.",
    tags = [&"hazard"],              # one, usually; two if it genuinely is both
    group = &"",                     # non-empty makes it ONE ONLY with siblings
    weight = 8,                      # 6-16; the table's own range
    min_danger = 3, max_danger = 6,  # the band from §3
    choices = [
        {label = "Do the risky thing",
            check = {attr = &"thermal", need = 5},
            met = func() -> Dictionary:
                Run.add_credits(OptionTable.purse(28))
                return {text = "..."},
            clean = func() -> Dictionary:
                return {text = "...", material = &"wreck"},
            partial = func() -> Dictionary:
                Run.heat += 6
                return {text = "..."},
            botched = func() -> Dictionary:
                Run.take_hull_damage(OptionTable.toll(4), "A death line.")
                return {text = "..."}},
        {label = "Spend something instead", effect = func() -> Dictionary:
            Run.fuel = maxi(0, Run.fuel - 9)
            return {text = "...", material = &"event"}},
        {label = "Leave it", stay = true, effect = func() -> Dictionary:
            return {text = "..."}},
    ],
},
```

**Attributes for `check`:** `sensors`, `thermal`, `stealth`, `thrust`, `hull`,
`salvage`. **Material tables for `material`:** `wreck`, `event`, `fauna`,
`fight`, `mining`.

**The second argument to `take_hull_damage` is a death line.** If that damage
kills you it becomes the run's epitaph on the game-over screen. Write it as a
cause of death, not a description of a scratch.

**An outcome's prose must describe exactly what its code does.** If a branch
calls `add_material`, the player is told something came aboard. If it calls
`take_hull_damage`, the words hurt. This has been broken twice and both times an
audit caught it, not a playtest.

---

## 5. Checking the work

```
python tools/encounter_lint.py --strict     # rulings; must be clean
godot --headless --path tkg -- optiontest   # 8 assertions, incl. reachability
bash .github/scripts/validate.sh            # the gate
```

`optiontest`'s **"every option has somewhere it could appear"** is the one that
catches a gate combination nothing satisfies. Four encounters were once
unreachable for weeks; that assertion is why it cannot happen again.

The linter currently reports **35 rulings and 15 review items on the existing
47**. Those are being fixed separately — do not fix them in this pass, and do
not copy their patterns.

---

## 6. What NOT to do

- **Do not touch the existing 47.** Append only.
- **Do not add a material without a reason.** If a new named item is genuinely
  needed, add it to `MaterialTable.gd` with `drops = &"named"` and update the
  census in that file's header. `LAST BROADCAST` is the worked example.
- **Do not rename an `id`.** Saves reference them.
- **Do not use `consume_material_tier`.**
- **Do not quote credit figures in prose.**
- **One word for a company: `manufacturer`.** Never house, maker, brand, or marque
  — `validate.sh` greps for those in both `tkg/scripts` and `docs` and fails
  the build on a hit. **Do not say berth** in
  anything a player reads; the identifiers keep it, the prose does not.

---

## 7. Review

`python tools/encounter_bench.py` regenerates a page with every encounter, its
branches, its ledger and the linter's findings, plus KEEP / REWRITE / CUT
buttons and a JSON export. Run it after the batch and hand the page over — that
is how these get judged, and it is much faster than reading a diff.
