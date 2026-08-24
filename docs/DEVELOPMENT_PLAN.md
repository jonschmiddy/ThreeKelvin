# Three Kelvin — Build Order

**TRIMMED 2026-08-24 to the part that is still true.**

This was a synthesis against five source documents, three of which
(`attributes-and-checks.md`, `card-design.md`, `manufacturer-identity.md`) and
one directory (`events/`) were never landed in the repo and still are not. Most
of what it asserted about the code was overtaken: Sensors and Stealth exist and
are displayed, the card dimension question was settled at 112×160 in
`CardView.gd`, card art shipped at 92×60 behind `ArtCheck.CARD_ART`, the grant
count law was reversed, and B6's "3–5% win rate" is now 16% Korvan-only / 22%
open pool at 500 runs.

**What survived is the argument about ORDER**, which no amount of drift makes
wrong, plus the balance spine. The state table (§0), the blocker list (§1) and
the file manifest (§5) were cut rather than corrected — they described a moment,
and `docs/archive/` is where moments are kept.

**Open ruling #11 — "does the game become an extraction deckbuilder?" — moved
to `coop-design.md` §16 ruling 1**, which is the same question, before this file
was cut. It is still open and is not part of any doc pass.

For where the code actually is, the honest answers are `-- content`, `-- sim`
and `.github/scripts/validate.sh`, none of which can go stale.

---

## 2. Phases

> **Blocker legend.** §1 was cut, but the phases below cite B1–B6 throughout.
> One line each, with what is true as of 2026-08-24:
>
> | | Was | Now |
> |---|---|---|
> | **B1** | batch-01 is built on run-state flags the whitelist defers | **Still open.** Events are still hardcoded lambdas — the single largest gap in the project |
> | **B2** | card dimensions frozen at a size the code contradicts | **Dead.** Settled at 112×160 in `CardView.gd`, with the reasoning in comments. Card art shipped at 92×60 per `ArtCheck.CARD_ART` |
> | **B3** | two incompatible manufacturer palettes | **Dead.** `Database.gd`'s `_seed_manufacturers()` is the one palette, `colour` + `field` per manufacturer |
> | **B4** | six of seven manufacturers are switched off | **Still true.** `DB.ACTIVE_MANUFACTURERS` is `[korvan]`. It is a balance event, not a data flip — the six-point win-rate gap is in `handbook.md` |
> | **B5** | existing events would fail the whitelist they're about to be held to | **Still open**, and blocked behind B1 |
> | **B6** | the economy is already lethal (3–5% win rate over 40 runs) | **Dead as stated.** 16% Korvan-only / 22% open pool at 500 runs. Read the current number off `-- sim`, never off this file |


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
- **Switch on the other six manufacturers (B4)** and take the balance hit
  deliberately, with the sim watching.

**Gate:** a build can reach Sensors 4 and Stealth 4 by giving up
something real, and all seven manufacturers have modules worth installing.

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

Phases 1–4 all push on the economy: six more manufacturers of loot, a deck-size
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
need a translation table from the CSV's manufacturer names to `MapGen.Region`.

**Gate:** each batch reviewed and merged before the next begins.

### Phase 9 — Identity art
*Implements `manufacturer-identity.md` §2. The palette was ruled in
Phase 2; this is the art that hangs off it.*

Seven emblems at ≤4 primitives each, surviving a 16px crop — that crop
*is* the HUD set-bonus chip, so it is a hard test. Banners across four
surfaces. All seven names are locked in `Database.gd`; no mark is draft on that account any more.

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
| 3 | Canonical manufacturer palette | B3 | Phase 8, chart tints |
| 4 | Three reds — resolve centrally in `UITheme` | B3 | Badge + hazard UI |
| 5 | When do the other six manufacturers switch on | B4 | Phases 4, 7, 8 |
| 7 | The met-threshold outcome tier rolls can't reach | §4.2 | Phase 2 authoring |
| 8 | Hard gate ratio — how many walls before walls stop mattering | §4.2 | Phase 4 |
| 9 | Do unique cards earn unique art | card §14 | Phase 8 |
| 10 | Do Criticals exist at MVP | card §14 | Phase 6 |

---


*Rows 2 (card dimensions) and 6 (hull 0–6 mapping) were dropped: the first is
*settled in `CardView.gd`, the second cites a section of a document that was
*never landed. Row 11 moved to `coop-design.md` §16.*
