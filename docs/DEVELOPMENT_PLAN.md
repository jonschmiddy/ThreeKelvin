# Three Kelvin — Build Order

Synthesis of `design-doc.md` v0.2, `attributes-and-checks.md` v0.3,
`card-design.md` v1.0, `manufacturer-identity.md` v0.1, and the events
contract (`EXPANSION.md` + `events-seeds.csv`), checked against the code
as it actually stands on `main` at `c48f2d1`.

The docs describe a game. This describes the order to build it in, what
is already built, and what has to be ruled on before certain tracks can
start at all.

---

## 0. Where the code actually is

The docs are written as though the attribute layer is greenfield. It
mostly isn't. **Four of the six attributes already exist as live system
numbers** — which is the core rule of `attributes-and-checks.md` §0
("every attribute is a number the game already tracks") already
satisfied by accident. The work is naming and surfacing them, not
inventing them.

| Attribute | Doc says | Code has | Work |
|---|---|---|---|
| Hull | Hit points | `RunState.hp` / `HullData.max_hull` | Name it; decide 0–6 mapping (§1.3 open) |
| Thrust | Fuel per jump, tow, reach | `HullData.fuel_factor`, `RunState.range_from()` | Derive a 0–6 value from existing numbers |
| Maneuverability | Dodge %, initiative | `HullData.dodge`, `HullData.initiative` | Derive; wire to combat entry |
| Thermal | Heat cap + dissipation | `HullData.heat_cap`, `dissipation` | Derive; add map signature |
| Sensors | Module-built, baseline 0 | *nothing* | New. Needs modules to exist first |
| Stealth | Module-built, baseline 0 | *nothing* | New. Needs modules to exist first |

Run-state meters:

| Meter | Code |
|---|---|
| Scrap | `RunState.scrap` ✅ |
| Fuel | `RunState.fuel` ✅ |
| Heat | `RunState.heat` ✅ |
| Notoriety | **missing** — no accumulator, no sources wired |

Other systems, measured rather than assumed:

- **Cards exist and work.** `CardData` carries energy/heat/damage/block/
  vent/charge and more; `DeckBuilder.build()` already assembles the deck
  from installed modules, which is the main doc's "your deck IS your
  modules" shipped and running.
- **Malfunctions half-exist.** `RunState.dross` is an unplayable card
  injected by spore enemies via `IntentData.dross`. That is
  `card-design.md` §11 in embryo — the catalog generalizes something
  already working, rather than adding a system.
- **All seven manufacturers are in `Database.gd`** with colours, set
  bonuses and taglines — but `ACTIVE_MAKERS` is `[&"korvan"]`. Six
  houses are defined and switched off.
- **Events are hardcoded lambdas.** `EventTable.build_all()` returns
  dictionaries of `Callable`s. There is no schema, no gate, no odds, no
  outcome band, and no way to validate an effect against a whitelist.
  This is the single largest gap between docs and code.

---

## 1. Blockers

Six things must be ruled on or recovered before the tracks they gate can
start. Four are cheap; two are real decisions.

### B1 — batch-01 is built on systems the whitelist defers ▲ critical
`batch-01.md` has been supplied and verified. **The README expected zero
violations; there are 30.** Full line-by-line in
[`events/batch-01-verification.md`](events/batch-01-verification.md).

Of 46 outcome bands, 16 parse against the MVP whitelist and one of those
violates the pile-on guard — **15 fully conforming, 33%.**

The finding is not drift. **The whitelist's DEFERRED list reads like an
inventory of batch-01's mechanics.** The two documents were written
against each other and never reconciled. `EXPANSION.md`'s own resolution
rule decides it:

> If an outcome wants to be remembered later, it isn't an MVP event.

About half of batch-01 is outcomes that want to be remembered later, by
design — the ghost that keeps spending your name, the lane that stays
open region-wide, the fence who prices you kindly for the rest of the
run. That is the best writing in the batch and exactly what the rule
excludes.

**Recommendation: promote run-state flags into the MVP.** They are the
single deferred system that unlocks the most — flags, price modifiers,
encounter suppression and remembered outcomes all hang off one
run-scoped key-value store — and they are already the acknowledged long
pole, since **9 of the 100 seeds are marked `deferred` for exactly this
reason**. Building it turns 13 of the 29 violating bands legal outright,
unlocks those 9 seeds, and makes batch-01 usable close to as written.
Everything else stays deferred and the few bands using it get authored
down.

Also unresolved: **card-design §15 blocks batch-02 on a ruling about
EVT-005 opt 4 and EVT-092 opt 2.** EVT-005 opt 4 is confirmed as the
batch's only pile-on. **EVT-092 is not in batch-01** — "The Free Lunch"
is `active` in the seed CSV but was never authored. §15 points at
content that does not exist.

### B2 — Card dimensions are frozen at a size the code contradicts ▲ critical
`card-design.md` §4 freezes hand scale at **96×130** and inspect at
**192×260**. `CardView.gd` is at **132×150**.

**This paragraph's arithmetic was wrong and its conclusion needs redeciding.**
It read: *"At 640×360 native, five cards at 96px wide is 480px and fits; five at
132px is 660px and does not fit on the screen. The doc's number is right and the
code is wrong."*

The game is not 640×360. `project.godot` says **960×540**, and has for as long as
anyone has looked. At the real width:

| five cards at | total | of 960 |
|---|---|---|
| 96px (`card-design.md`) | 480px | 50% |
| 132px (`CardView.gd`) | 660px | 69% |

Both fit. The reason given for calling the code wrong does not exist, so the
conflict between 96 and 132 is now an open design question about how much of the
screen a hand should occupy — not a bug with a known answer. Settle it by putting
both on screen, the same way the hull box sizes were settled.

Every card sprite, the fan layout and the inspect view still inherit whichever
number wins, so it should be settled before any card art is commissioned.

### B3 — Two incompatible manufacturer palettes ■ major
`Database.gd` and `manufacturer-identity.md` disagree on all seven
houses:

| House | In code | In identity doc |
|---|---|---|
| Korvan | `#8a6a3a` | `#8a4517` |
| Solari | `#b1531f` | `#ef9f27` |
| Dredge | `#6b6250` | `#6e5a2e` |
| Redline | `#5a7a6a` | `#e24b4a` |
| Veyra | `#8a7a9a` | `#e8e0cc` |
| Cygnet | `#5a7a94` | `#16202e` |
| Calyx | `#6a8a6a` | `#e2ece6` |

The code's palette was deliberately desaturated to sit quietly behind
chart icons — and was then *removed from the starchart entirely* this
session, because the houses were too close together to tell apart
(`#5a7a6a` Redline vs `#6a8a6a` Calyx). The identity doc's palette is
far more separable and is the better source of truth.

**Ruling needed:** adopt the identity palette as canonical and derive a
muted chart variant from it, rather than keeping two independent sets.
Note the doc's own §1 collision warning — Redline `#e24b4a` sits next to
the odds ladder's 5% red, and now also next to the starchart's hazard
red `#d4614f`. **Three reds.** Worth resolving once, centrally, in
`UITheme`.

### B4 — Six of seven houses are switched off ■ major
`ACTIVE_MAKERS = [&"korvan"]`. Meanwhile `attributes-and-checks.md` §1.5
assigns attribute signatures to all seven, §8 tags event pools by house
territory, and `manufacturer-identity.md` specs seven banners.

Turning them on is a balance event, not a data flip — it multiplies the
loot pool and changes every set-bonus calculation. It gates the
region-tagged event pools (§8) and most of the identity art.

### B5 — Existing events would fail the whitelist they're about to be held to ■ major
`README.md` demands every effect line in batch-01 parse against the MVP
whitelist. The events already in the game would not pass the same test —
`Run.heat_cap_bonus += 3` (Coolant seller) is a permanent capacity
change, which is not a listed effect.

Not a crisis, but the validator must be written knowing that the
existing content needs porting or retiring, not just the new content
checking.

### B6 — The economy is already lethal ● watch
Sim over 40 runs: **3–5% win rate** against the doc's 40–55% target, and
**22.5% stranded**. Everything in these documents pushes difficulty
*up*: checks that read damaged gauges, hard gates, malfunction pollution,
deck bloat.

**This is the reason the phase order below puts systems before content.**
Authoring 90 events against an economy that kills 95% of runs means
authoring them twice.

---

## 2. Phases

**The ship half first, the event half second.** These documents describe
two bodies of work: hulls, modules, cards and attributes on one side;
schema, checks and content on the other. The second reads the first and
nothing flows back. Building the event layer against a module system
that the verb model is about to reshape would mean building it twice.

This ordering also resolves a dependency the docs half-state and this
plan originally got wrong. **Sensors and Stealth are module-built from a
baseline of zero.** With one manufacturer active and a thin catalog,
there is nothing to build a Sensors 4 ship out of — so an event checking
Sensors 4 is unplayable no matter how well the schema works. Modules
come before attributes, and attributes before checks.

Two consequences for the blockers:

- **B1 and B5 stop being blockers and become decisions with a deadline.**
  Better still, the run-state-flags question gets easier to answer later:
  once the ship half is built, you will know how much run-scoped state
  the game already carries, which is most of the cost of that ruling.
- **B3 gets more urgent, not less.** Modules are manufacturer-branded.
  Expanding the catalog means committing to a palette, so the two
  incompatible sets have to be reconciled in Phase 2, not Phase 9.

Each phase names the gate that says it's done.

### Phase 1 — Card and module foundations
*Implements `card-design.md` §13.1–4.*

- Dimensions per B2, both scales, exact 2×. Settle this before any card
  art exists to be redone.
- Zone map: corner grammar (energy left, heat right, **always printed**),
  panel insets, type line, provenance footer.
- Verb/grant data model — verbs are shapes, modules are magnitudes.
- **Grant Count Law**: count fixed by module class, rarity upgrades
  rather than adds, uniques replace. Displayed as `Grants: 2`.
- Install-time deck delta (`deck 14 → 15`).

**Gate:** a rarer module never produces a larger deck than its common
sibling, and the ship screen shows the delta at the point of choice.

### Phase 2 — The module catalog
*Implements B3, B4, and the half of `attributes-and-checks.md` §1.2 that
has no code at all.*

- **Modules that carry Sensors and Stealth.** These two attributes have
  no existence outside modules, and the whole see/be-seen axis — §1.1's
  structural spine — is currently a specification with nothing behind it.
- Enough catalog depth that reaching 4+ on either is a real build
  decision competing with weapons for slots, per §1.2.
- **Rule B3 and adopt one canonical palette.** Modules are branded;
  every module added under two palettes is a module to re-colour later.
- **Switch on the other six houses (B4)** and take the balance hit
  deliberately, with the sim watching.

**Gate:** a build can reach Sensors 4 and Stealth 4 by giving up
something real, and all seven houses have modules worth installing.

### Phase 3 — Attributes exist and are visible
*Implements `attributes-and-checks.md` §10.1.*

- Derive the four chassis attributes from the gauges that already exist.
  **Read them — do not add parallel fields.**
- Settle the Hull 0–6 mapping. Recommend `current_hp / (max_hp / 6)`
  floored; percentage bands need a second authoring vocabulary for no gain.
- Sum Sensors and Stealth from installed modules — now possible.
- `RunState.notoriety` plus its four sources: kills, contraband carried,
  wrecks looted, fights fled.
- HUD: two visually separate clusters. Abbreviations live here and
  nowhere else, per §7.4.

**Gate:** six attributes and four meters on the HUD, all derived, and
taking hull damage visibly lowers the Hull check value.

### Phase 4 — Malfunctions
*Implements `card-design.md` §11. Generalizes `dross`.*

Belongs here rather than after events: it is a card and module system,
and `RunState.dross` already works. Events become one more source later.

- Twelve-entry catalog; severity sets the removal price.
- Inert and Patchable at minimum. **Active needs an on-draw hook and
  "Jammed Feed" needs a retain hook** — if either misses, ship the other
  two and hold the marked entries, exactly as §11.3 says.
- Origin strings replace the module in the footer.
- Station junk-removal priced by severity.

**Gate:** a malfunction from any source shows its origin, and station
removal prices by severity.

### Phase 5 — Balance
*Not in any document. Inserted because of B6, and now sitting where it
belongs — after the systems that move the numbers.*

Phases 1–4 all push on the economy: six more houses of loot, a deck-size
law, malfunction pollution. Tune once, afterwards, rather than chasing
it four times.

Levers already identified: the range multiplier, the third-nearest
floor, `FUEL_PER_DISC_RADIUS`, the pulsar trade, and station repair
pricing — the main doc's stated first lever. Also fix the 22.5% stranded
rate; pulsar nodes now sit off the layout grid `_link` builds from.

**Gate:** 200 sim runs inside 40–55%, stranded under 10%, **and five
full runs played by hand.** The sim models a competent player, not a
new one.

### Phase 6 — Attributes have consequences
*Implements §10.5–7. Cheap once Phase 3 lands.*

- MNV → combat entry state. **Failure changes terms, never outcome** —
  the asymmetric miss rule holds.
- SEN → the pre-jump reveal ladder. The starchart already filters
  visibility, so this is a depth parameter on existing machinery.
- THM signature net of STL, plus Notoriety → encounter **composition**
  weighting. Never difficulty (§3.1), or loud famous builds death-spiral
  in the core.

**Gate:** two builds with different Sensors values see measurably
different pre-jump information on the same node.

### Phase 7 — Events become data
*Implements §10.2–4 and the events contract. Everything it checks now
exists.*

- **Rule B1 first.** By this point you will know how much run-scoped
  state the ship half carries, which is most of the cost of deciding
  whether run-state flags come into the MVP.
- Event resource schema replacing `EventTable`'s lambdas.
- Four option types; checks read **current** values.
- Odds ladder 100 / 65 / 40 / 20 / 5, shortfall-driven.
- Three outcome bands; Partial gets the design effort.
- **Whitelist validator that runs at load and fails loudly.**
- Badge grammar per §7.3.
- Port or retire the existing hardcoded events (B5).

**Gate:** batch-01 loads, every effect parses, zero violations, and a
shortfall option reads `Hull 5 · you have 3 · 65%`.

### Phase 8 — Event content
*Implements the `EXPANSION.md` process.*

90 active seeds, batches of ten, **human review between every batch**.
Skip `deferred` and `reserved`; EVT-101 is hand-authored. Region pools
need a translation table from the CSV's house names to `MapGen.Region`.

**Gate:** each batch reviewed and merged before the next begins.

### Phase 9 — Identity art
*Implements `manufacturer-identity.md` §2. The palette was ruled in
Phase 2; this is the art that hangs off it.*

Seven emblems at ≤4 primitives each, surviving a 16px crop — that crop
*is* the HUD set-bonus chip, so it is a hard test. Banners across four
surfaces. Veyra and Calyx marks stay **draft until their names lock**.

**Gate:** every emblem legible at 16px.

## 3. Running alongside

**The balance spine.** `HeadlessSim` is the only thing in this project
that answers "is this playable" without a human playing it. Every phase
that touches the economy — 3, 5, 6 — re-runs it. It found the 22.5%
stranded regression this session that no amount of reading would have.

**The measurement habit.** Four separate multi-round debugging loops this
session were resolved by instrumenting and measuring, after reasoning had
failed. Applies equally here: before tuning the economy, print the
distributions.

---

## 4. Open rulings

Carried from the source documents, plus what this synthesis surfaced.
Each needs a human decision.

| # | Ruling | From | Blocks |
|---|---|---|---|
| 1 | Promote run-state flags into MVP, or author batch-01 down | B1 | Phase 4 entirely |
| 1b | EVT-092 opt 2 — §15 names content that does not exist | B1 | batch-02 |
| 2 | Card dimensions: adopt 96×130 | B2 | Phase 5, all card art |
| 3 | Canonical manufacturer palette | B3 | Phase 8, chart tints |
| 4 | Three reds — resolve centrally in `UITheme` | B3 | Badge + hazard UI |
| 5 | When do the other six houses switch on | B4 | Phases 4, 7, 8 |
| 6 | Hull 0–6 mapping: derived value vs bands | §1.3 | Phase 1 |
| 7 | The met-threshold outcome tier rolls can't reach | §4.2 | Phase 2 authoring |
| 8 | Hard gate ratio — how many walls before walls stop mattering | §4.2 | Phase 4 |
| 9 | Do unique cards earn unique art | card §14 | Phase 8 |
| 10 | Do Criticals exist at MVP | card §14 | Phase 6 |
| 11 | **Does the game become an extraction deckbuilder?** `coop-design.md` v0.2 overturns the no-meta-progression ruling stated in `RunHistory.gd` and `design-doc.md`. Persistent collection, per-dive scrap, win = reach the rim alive. | coop §16.1 | Every phase below. Decide before Phase 3 (economy) |

---

## 5. Files to land

The design kit is **not in the repo yet**. Per `README.md`:

```
ThreeKelvin/
├── design-doc.md                 ✅ present
├── coop-design.md                ✅ present — co-op + extraction layer, v0.2 draft
├── attributes-and-checks.md      ❌ missing
├── card-design.md                ❌ missing
├── manufacturer-identity.md      ❌ missing
├── DEVELOPMENT_PLAN.md           ✅ this file
└── events/
    ├── EXPANSION.md              ❌ missing
    ├── events-seeds.csv          ❌ missing
    ├── batch-01.md               ⚠ supplied, encoding-damaged — land the clean original
    └── batch-01-verification.md  ✅ this session
```

`README.md`'s own tree omits `card-design.md` and `manufacturer-identity.md`;
`card-design.md` §15 already flags this as a required delta. Fix on landing.
