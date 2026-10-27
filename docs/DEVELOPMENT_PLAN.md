# Three Kelvin — Build Order

**BROUGHT UP TO DATE 2026-10-23, after the alphas 0.1.0 to 0.4.2.** Each of
phases 1 to 9 now says what is done, with the build or commit that did it, what
is partly done, and what is left. Phases 10 to 15 are the work after the alpha,
from the friends' playtest of Oct 22 and 23 (Kevin, Cody, Geno and Jeremy). The
record behind every status line is `CHANGELOG.md`, `HANDOFF.md` and `git log`.

**TRIMMED 2026-08-24 to the part that is still true.**

This was a synthesis against five source documents, three of which
(`attributes-and-checks.md`, `card-design.md`, `manufacturer-identity.md`) and
one directory (`events/`) were never landed in the repo and still are not. Most
of what it asserted about the code was overtaken: Sensors and Stealth exist and
are displayed, the card dimension question was settled at 112×160 in
`CardView.gd`, card art shipped at 92×60 behind `ArtCheck.CARD_ART`, and the
grant count law was reversed.

**What survived is the argument about ORDER**, which no amount of drift makes
wrong, plus the balance spine. The state table (§0), the blocker list (§1) and
the file manifest (§5) were cut rather than corrected. They described a moment,
and `docs/archive/` is where moments are kept.

**Open ruling #11, "does the game become an extraction deckbuilder?", moved
to `coop-design.md` §16 ruling 1**, which is the same question, before this file
was cut. It is still open and is not part of any doc pass.

For where the code actually is, the honest answers are `-- content`, `-- sim`
and `.github/scripts/validate.sh`, none of which can go stale.

---

## 2. Phases

> **Blocker legend.** §1 was cut, but the phases below cite B1 to B6 throughout.
> One line each, with what is true as of 2026-10-23:
>
> | | Was | Now |
> |---|---|---|
> | **B1** | batch-01 is built on run-state flags the whitelist defers | **Half answered.** The flag store was never built, because the option system carries run state instead: an option can place options elsewhere on the map (`docs/briefs/ENCOUNTER_GENERATION.md`), and since 0.4.1 such a follow-up is a row in QUESTS (`Run.event_quests`, ad962625). Events are still lambdas in `OptionTable`, which is the half Phase 7 still owes |
> | **B2** | card dimensions frozen at a size the code contradicts | **Dead.** Settled at 112×160 in `CardView.gd`, with the reasoning in comments. Card art shipped at 92×60 per `ArtCheck.CARD_ART` |
> | **B3** | two incompatible manufacturer palettes | **Dead.** `Database.gd`'s `_seed_manufacturers()` is the one palette, `colour` + `field` per manufacturer |
> | **B4** | six of seven manufacturers are switched off | **Still true for five of seven.** `DB.ACTIVE_MANUFACTURERS` is `[korvan, solari]`. Since 0.2.0 a manufacturer you have not unlocked appears nowhere (19903ad1), and since 0.4.2 a win unlocks by the manufacturer you launched with (674c314a). Writing the other five is after the alpha |
> | **B5** | existing events would fail the whitelist they're about to be held to | **Mostly dead.** `tools/encounter_lint.py --strict` runs in the gate and fails on anything new. Fifteen findings that predate it are held in `tools/encounter_lint_baseline.txt` |
> | **B6** | the economy is already lethal (3 to 5% win rate over 40 runs) | **Dead as stated.** The Oct 22 balance (Phase 5) moved every number. Read the current one off `-- sim`, never off this file |


**The ship half first, the event half second.** These documents describe
two bodies of work: hulls, modules, cards and attributes on one side;
schema, checks and content on the other. The second reads the first and
nothing flows back. Building the event layer against a module system
that the verb model is about to reshape would mean building it twice.

This ordering also resolves a dependency the docs half-state and this
plan originally got wrong. **Sensors and Stealth are module-built from a
baseline of zero.** With one manufacturer active and a thin catalog,
there is nothing to build a Sensors 4 ship out of, so an event checking
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

### Phase 1 — Card and module foundations — **done**
*Implements `card-design.md` §13.1 to 4.*

- Dimensions per B2, both scales, exact 2×. Settle this before any card
  art exists to be redone.
- Zone map: corner grammar (energy left, heat right, **always printed**),
  panel insets, type line, provenance footer.
- Verb/grant data model: verbs are shapes, modules are magnitudes.
- **Grant Count Law**: count fixed by module class, rarity upgrades
  rather than adds, uniques replace. Displayed as `Grants: 2`.
- Install-time deck delta (`deck 14 → 15`).

**Gate:** a rarer module never produces a larger deck than its common
sibling, and the ship screen shows the delta at the point of choice.

**Status, Oct 23: met, all of it in 0.1.0-alpha.1.**

- Cards are 112×160 (`CardView.CARD_W`, `CARD_H`). Energy is top left and heat
  top right on every card.
- The provenance footer was cut on purpose. The text box runs to the bottom of
  the card, and rarity is the colour of the name (`CardView.gd`).
- The Grant Count Law was replaced by a stricter one: **every module grants
  exactly two cards**, and Verity grants one (`docs/catalogue.md` §2,
  `ModuleData.grant_count()`). Rarity can only make the cards better, so the
  gate holds by construction.
- The deck delta is drawn as `deck 14 → 15` (`Widgets.gd`).

### Phase 2 — The module catalog — **partly done**
*Implements B3, B4, and the half of `attributes-and-checks.md` §1.2 that
has no code at all.*

- **Modules that carry Sensors and Stealth.** These two attributes have
  no existence outside modules, and the whole see/be-seen axis, §1.1's
  structural spine, is currently a specification with nothing behind it.
- Enough catalog depth that reaching 4+ on either is a real build
  decision competing with weapons for slots, per §1.2.
- **Rule B3 and adopt one canonical palette.** Modules are branded;
  every module added under two palettes is a module to re-colour later.
- **Switch on the other six manufacturers (B4)** and take the balance hit
  deliberately, with the sim watching.

**Gate:** a build can reach Sensors 4 and Stealth 4 by giving up
something real, and all seven manufacturers have modules worth installing.

**Status, Oct 23.**

- **Done:** modules carry Sensors and Stealth, and both do work (Phase 6). The
  palette is ruled (B3). Korvan and Solari are full manufacturers: 95 modules
  in all at 0.1.0, Solari with 25 parts and 40 cards (`docs/catalogue.md`).
- **Fixed since:** a part that rolled a grade up now gets that grade's pips. A
  Rare Ranging Optics read SENSORS +1 and added nothing (5ec934e7, 0.4.2).
- **Left:** the other five manufacturers. They can be unlocked and flown, but
  have 4 to 7 parts each, use Korvan's hull art, and their set bonuses cannot be
  completed (`HANDOFF.md`, Known issues). `docs/building-a-manufacturer.md` is
  the method. The first half of the gate was not re-measured for this pass.

### Phase 3 — Attributes exist and are visible — **done, less Notoriety**
*Implements `attributes-and-checks.md` §10.1.*

- Derive the four chassis attributes from the gauges that already exist.
  **Read them, do not add parallel fields.**
- Settle the Hull 0 to 6 mapping. Recommend `current_hp / (max_hp / 6)`
  floored; percentage bands need a second authoring vocabulary for no gain.
- Sum Sensors and Stealth from installed modules, now possible.
- `RunState.notoriety` plus its four sources: kills, contraband carried,
  wrecks looted, fights fled.
- HUD: two visually separate clusters. Abbreviations live here and
  nowhere else, per §7.4.

**Gate:** six attributes and four meters on the HUD, all derived, and
taking hull damage visibly lowers the Hull check value.

**Status, Oct 23.**

- **Done, in 0.1.0-alpha.1:** all six attributes are derived, never stored
  (`RunState.attr_hull` to `attr_stealth`). They show on the ship screen, the
  cutaway and the chassis select, with what the chassis gives drawn apart from
  what the parts add. They are not on the HUD bar, which carries hull, heat,
  credits and fuel.
- **Corrected:** the Hull mapping is not 0 to 6. Every attribute is read on a
  scale of 10 (`ATTR_MAX`) and can go past it, and Hull reads current hull
  against a fixed 70 (`HULL_REF`),
  not against your own maximum, so a bigger frame and damage both count. Taking
  damage lowers it, which is the gate's second half.
- **Done:** heat takes up to 4 off Stealth (`HEAT_STEALTH_COST`).
- **Left:** Notoriety. Nothing in the code tracks it.

### Phase 4 — Malfunctions — **partly done, built another way**
*Implements `card-design.md` §11. Generalizes `dross`.*

Belongs here rather than after events: it is a card and module system,
and `RunState.dross` already works. Events become one more source later.

- Twelve-entry catalog; severity sets the removal price.
- Inert and Patchable at minimum. **Active needs an on-draw hook and
  "Jammed Feed" needs a retain hook.** If either misses, ship the other
  two and hold the marked entries, exactly as §11.3 says.
- Origin strings replace the module in the footer.
- Station junk-removal priced by severity.

**Gate:** a malfunction from any source shows its origin, and station
removal prices by severity.

**Status, Oct 23.**

- **Done, in 0.1.0-alpha.1, another way:** sixteen malfunctions
  (`Database.MALFUNCTIONS`) built from three keywords, Corrode, Smoulder and
  Fused, all charged at the end of your turn rather than on the draw
  (`docs/catalogue.md` §10). Enemies put them in your deck.
- **Done:** a shipyard's FAULTS drone clears one, and you pick which card.
- **Not as specified:** removal is priced per removal by the station
  (`Market.purge_price`), not by severity. There is no footer to carry an
  origin; a malfunction wears its own banner with a break mark. Events are not
  a source yet. The gate as written is not met, and nobody has asked for it
  since.

### Phase 5 — Balance — **partly done**
*Not in any document. Inserted because of B6, and now sitting where it
belongs, after the systems that move the numbers.*

Phases 1 to 4 all push on the economy: six more manufacturers of loot, a deck-size
law, malfunction pollution. Tune once, afterwards, rather than chasing
it four times.

Levers already identified: the range multiplier, the third-nearest
floor, `FUEL_PER_DISC_RADIUS`, the pulsar trade, and station repair
pricing, the main doc's stated first lever. Also fix the 22.5% stranded
rate; pulsar nodes now sit off the layout grid `_link` builds from.

**Gate:** 200 sim runs inside 40 to 55%, stranded under 10%, **and five
full runs played by hand.** The sim models a competent player, not a
new one.

**Status, Oct 23.** Kevin, the first outside playtester, reached the core in
seven jumps and nearly beat the Custodian in a starter ship (Oct 22). Jon ruled
for a hard game, and 0.4.0-alpha.1 carries all of it:

- **One ring deeper per jump, at most** (`RunState.DEPTH_STEP`, b28fdad6). The
  shortest way to the core went from as few as 4 jumps to 14. The chart says
  TOO DEEP and ONE RING AT A TIME, and every galaxy keeps a way into each ring.
- **The Custodian:** hull 120 to 200 (b28fdad6), and it lost Plated Up, so
  Annihilate lands every third turn for 40, up from 22 (7790b9f5). In the sim a
  built ship wins 56% of arrivals, a human-like pilot 39%, and a starter never.
- **Deep loot:** no common parts or materials from danger 5 in, and epic,
  legendary and artifact materials as deep as the parts of the same grade
  (27d7f6eb).
- **Corrected:** jump reach is a fixed 0.18 (`JUMP_RADIUS`) again. The relative
  range and the third-nearest floor now set sight, not reach.
- **The run-length study** (577472bb) is how these were chosen: a beeline
  pilot, a shortest-path harness, and study flags that are off unless given.
- **Left:** the whole-run win rate and the stranded rate were not re-measured
  for this pass. The 40 to 55% band was set before the Oct 22 ruling. Hand play
  now comes from playtesters, and Phase 11 picks the fight half up.

### Phase 6 — Attributes have consequences — **partly done**
*Implements §10.5 to 7. Cheap once Phase 3 lands.*

- MNV → combat entry state. **Failure changes terms, never outcome.**
  The asymmetric miss rule holds.
- SEN → the pre-jump reveal ladder. The starchart already filters
  visibility, so this is a depth parameter on existing machinery.
- THM signature net of STL, plus Notoriety → encounter **composition**
  weighting. Never difficulty (§3.1), or loud famous builds death-spiral
  in the core.

**Gate:** two builds with different Sensors values see measurably
different pre-jump information on the same node.

**Status, Oct 23.**

- **Met, in 0.1.0-alpha.1: SEN.** Sight is a radius that grows a quarter per
  pip (`SENSE_FLOOR`, `SENSE_REACH`). A star in thruster reach but out of sight
  reads NOT SCANNED and cannot be jumped to. An event's fight reads "Fight."
  under 3 sensors, a contact count from 3, and a word about the enemy from 6
  (`EncounterDrawer.contact_reading`).
- **Built, in a different form: STL.** Heat signature gates an ambush on
  arrival, danger scales it, and Stealth takes up to 60% off
  (`RunState.ambush_chance`). It moves how often, not what comes.
- **Partly: MNV.** It is dodge in a fight and the FLEE check
  (`Combat.FLEE_ATTR`). Combat entry state is not built; initiative is read
  nowhere in a fight.
- **Left:** Notoriety, and with it composition weighting.

### Phase 7 — Events become data — **partly done**
*Implements §10.2 to 4 and the events contract. Everything it checks now
exists.*

- **Rule B1 first.** By this point you will know how much run-scoped
  state the ship half carries, which is most of the cost of deciding
  whether run-state flags come into the MVP.
- Event resource schema replacing `EventTable`'s lambdas. (`EventTable` was deleted 2026-08-27; its entries live in `OptionTable`, still as lambdas.)
- Four option types; checks read **current** values.
- Odds ladder 100 / 65 / 40 / 20 / 5, shortfall-driven. (Built: `SkillCheck`.)
- Three outcome bands; Partial gets the design effort.
- **Whitelist validator that runs at load and fails loudly.** (Built as a gate step instead: `tools/encounter_lint.py --strict`.)
- Badge grammar per §7.3.
- Port or retire the existing hardcoded events (B5).

**Gate:** batch-01 loads, every effect parses, zero violations, and a
shortfall option reads `Hull 5 · you have 3 · 65%`.

**Status, Oct 23.**

- **Done, in 0.1.0-alpha.1:** the odds ladder, checks on current values, and
  four bands: MET (meeting a check is certain, no roll), CLEAN, PARTIAL and
  BOTCHED (`SkillCheck`). The badge reads `HULL 5 · you have 3 · 65% · likely`,
  the gate's line plus a word for the odds. The lint is in the gate (B5).
- **Done since:** every result that gives loot shows REWARD (4d1cadfa, 0.4.0).
  A signed contract puts its pickup or target in the system its note names
  (c9173534, 0.4.0). An event's follow-up is a row in QUESTS (ad962625, 0.4.1).
- **Left:** the schema. Every encounter is still a lambda in `OptionTable`.

### Phase 8 — Event content — **done another way**
*Implements the `EXPANSION.md` process.*

90 active seeds, batches of ten, **human review between every batch**.
Skip `deferred` and `reserved`; EVT-101 is hand-authored. Region pools
need a translation table from the CSV's manufacturer names to `MapGen.Region`.

**Gate:** each batch reviewed and merged before the next begins.

**Status, Oct 23.** 135 encounters are authored in `OptionTable`, the last 80
under `briefs/ENCOUNTER_COMMISSION.md`, and about 43 weather events play on the
sector map (0.1.0-alpha.1). The gate checks the prose with `prose_grade.py` and
`prose_tells.py`. New event content after the alpha is Phase 12.

### Phase 9 — Identity art — **done**
*The palette was ruled in Phase 2; this is the art that hangs off it. The
citation to `manufacturer-identity.md` §2 is struck. See the footnote.*

Seven emblems at ≤4 primitives each, surviving a 16px crop. That crop
*is* the HUD set-bonus chip, so it is a hard test. Banners across four
surfaces. All seven names are locked in `Database.gd`; no mark is draft on that account any more.

**Gate:** every emblem legible at 16px. **Met.** All seven read at 16 and at
the 13 the badge actually draws, and, the harder half, read as seven
*different* things. `tools/` has no part in this: the marks are rectangles in
`CardView.draw_emblem`, so the test is to render them and look.

Most of this phase turned out to be built already and never measured. What
finishing it actually took:

- **The chip the gate is named after did not exist.** `Run.has_set` has been
  deciding whether Solari plasma gains damage and whether Cygnet drones act
  twice for as long as those bonuses have existed, and the player was told
  nowhere. The only place a set bonus appeared was the chassis picker, which
  is the one screen you are not on while it matters. `HudBar`'s own header
  claimed "live set-bonus progress" and the file contained none. It does now,
  at exactly 16px, which is where the gate's number came from.
- **The bar had seven pixels of slack and the chip wanted sixteen.** Measured,
  not eyeballed: `-- stationshot` prints the row's wanted width against its
  real one. Separation went 6 → 5, the same lever this file's header records
  pulling once before, and the bar now wants less *with* the chip than it did
  without.
- **The fourth banner surface is the station header.** A territory station
  stocks its shelf from one manufacturer and prints its contracts in that
  manufacturer's voice, and never said whose. The flag rather than the badge:
  the chassis list badges seven you are choosing between, this is the one you
  are inside of. A station nobody holds hides it rather than flying a blank.
- **Redline's hem was eating Redline's mark.** Its strips ran sixteen units up
  a twenty-two unit flag, straight through the emblem at unit 11: two bars of
  the mark colour on a column of the mark colour. Replaced with a short hem and
  two threads pulled long; nothing in it now goes above eight.

**Ruling: the primitive budget counts SHAPES, not draw calls.** A row of
identical teeth drawn in a loop is one shape; a narrowing stack is one shape.
Under draw calls `probate` is six rects and fails a budget of four, and it
cannot come down without becoming a different mark. Under shapes it is a bucket
and its teeth, and every emblem passes. The budget was only ever a proxy for
legibility at 16px, and that is gated directly, so the proxy defers to it.
`solari` came down 5 → 3 anyway. Opposite rays are collinear and touch the
disc, so one bar through does the work of two stubs, and the render is byte
identical.

### What the alphas added that no phase named

Built between Oct 20 and Oct 23, from Jon's play and the playtests. Listed so
the phases above are not read as the whole of the game.

- **A deep tutorial.** A.S.H. teaches the audit's 35 lessons, each the first
  time it matters, paced by the game, voiced from Jon's picks of three takes
  (5c221f81, 8e140bac, 0.4.0). She cannot be clicked away: a line stays until
  you do what it teaches (b54214f1, 0.4.0). Since 0.4.2 she never says a line
  aloud twice (9e1e58cf).
- **QUESTS and COMMS.** QUESTS is a tab on the top bar with every signed job and
  event quest, SHOW ON STARCHART and PLOT ROUTE (21017bc8, 0.4.0), and finished
  ones under COMPLETED (ad962625, 0.4.1). COMMS lists everything A.S.H. has said
  this run and plays it again (9e1e58cf, 0.4.2).
- **Co-op fights are shared.** Every ordinary fight can be joined with JOIN
  FIGHT, partners fly on the sector map, and a galaxy mismatch is said on screen
  and in godot.log (851b2834, 65140cf1, 0.4.0). An event quest and a contract's
  work are per ship (74a94c48, 0.4.1).
- **The ARCHIVE is gone.** Its tab, its title entry and its 41 documents were
  removed (551ef568, 0.4.0).
- **LOCAL does what GO does.** Opening LOCAL at a place with an event opens that
  event, and LOCAL draws no stand-in picture (1a16d049, 0.3.2).
- **Docking and undocking** play as one arrival with the camera still, the
  station powering on with sound (0.2.0 to 0.3.2).
- **Ship pictures show weapons only.** Systems and utilities stay fitted and
  still show in the cutaway and on the refit screen (2c75081b, 0.4.2).
- **Lock on stacks**, and the next attack spends all of it (aecebc51, 0.4.2).
- **A full ship stays full** when a part with hull is fitted (9bc71393, 0.4.2).

### Post-alpha: phases 10 to 15

From the friends' alpha (Cody, Geno, Jeremy, Kevin), Oct 22 to 27. Updated
Oct 27 with Jeremy's orbital notes and Geno's later reports.

**Order.** 10 first. Phase 11's study and Phase 13's mock page run alongside it
(machine time and a page, not code). Then 11, 12 and 13's build. 14 waits for
the alpha to end. 15 is design only.

**Already fixed in 0.4.2** (Oct 23), not repeated below:
- **Hull-swap softlock:** parts stranded on the pad, no UNDOCK (Geno).
- **Solari unlock:** a win unlocks Solari even after ending in another hull (Geno).
- **Grade pips:** higher-grade loot gives its pips (Geno).
- **Hull gauge:** fitting hull plating moves the HULL gauge at once (Geno).
- **A.S.H.:** no longer repeats herself, and COMMS lists what she said (Jeremy).
- **Weapons only** are drawn on the ship (Geno).
- **Lock on stacks** (Jon).

### Phase 10 — Alpha bugs and small UX
*About 2 to 3 days. No dependencies.*

- **Derelict hauler hides what you are claiming** (Jeremy). "Claim the hull"
  rolls the frame only after the choice, so a heavy pilot learned it was light,
  declined, and lost the strip option with it. Fix: roll the frame from the
  system's seed before the choice, and name its weight in the label ("Claim the
  hull (a light frame)"). A found hull you decline can be scrapped for what
  "Strip it" pays. Recommended; no ruling needed.
- **"Too deep" beside you near the top of the map** (Geno; Jon's chart
  screenshot). The chart is drawn tilted, so near its top and bottom edges two
  stars side by side on screen can be rings apart, and the one-ring rule refuses
  them with no warning before the click. Two parts:
  (a) dim stars in reach that are too deep (ruled A, Oct 27);
  (b) switch to two rings per jump (ruled Oct 27), then re-tune the Custodian
  against it.
- **LOCAL lets you leave a station too easily** (Jeremy). Ruled Oct 27: LOCAL is greyed out
  while docked ("Docked. Press UNDOCK to leave."); UNDOCK is the only way out.
- **Chassis select hull against pips** (Geno; ruled C, Oct 27: show the real hull beside the pips).
- **The sector map's ship should be the player's own ship** (Jeremy).
- **Blue ion engine flames on the sector map** (Jeremy). This is the first half
  of Phase 13's "two engines".

**Gate:** each item closed or ruled out by Jon.

### Phase 11 — Make combat matter
*Jeremy: "combat doesn't feel important", "encounters are way too fast for how
infrequent they are", "combats need to feel epic". Cody dove star to star.*

1. **A sim study** of all ship health at 1.5×, 2× and 3×, plus a variant where
   everything hits harder. Measure turns per fight, hull lost per fight, fights
   lost, the run win rate and **credits at the end of a won run** (Geno won with
   Solari holding about 5,900 credits; is the economy loose at the end?). Machine
   time only: about 2 hours on the PC, about 4 on the Mac. It can start during
   Phase 10.
2. **Pick and apply the health and damage change** (open ruling 14). Hours.
   Depends on step 1.
3. **A second combat resource** (Jeremy). A design project: a page of options
   first, then a build of days to a week. Depends on step 2, since both change
   how long a fight lasts.
4. **Epic battle music and a "legendary" boss track.** Jeremy loves the flying
   music. Pick reference tracks first, then generate. It costs ElevenLabs
   credits, which need Jon's OK.
5. **Re-run the Custodian balance** after steps 2 and 3. It was tuned on Oct 22
   to a 56% win rate for a built ship.

**Gate:** fights measurably longer and costlier per the step 1 study, the
Custodian re-tuned, and Jon's pick on each step that needs one.

### Phase 12 — Things to do between fights
*Jeremy: science on barren planets, comet interception, explorable asteroids,
colonisation; "make science and exploration offset the infrequentness of
combats". About 1 to 2 weeks. Depends on Phase 11's decision on how rare and how
long fights are.*

- **One "science" event family** tied to places already on the map: barren
  worlds, comets (intercept) and asteroid belts. New event types plus their
  rewards. A comet intercept pairs with Phase 13's flight: catching it is a
  flight problem as well as an event.
- The writing goes through the encounter-prose skill: the plain voice, grade 7.
  The art goes through PixelLab within its allowance.
- **Colonisation is later**, with its own design.

**Gate:** the family is in `OptionTable`, passes the gate's lint and prose
steps, and each batch is reviewed before the next.

### Phase 13 — Flight and orbits
*Jeremy, with references: the ASTE-589 optimal-transfer PDF and its MATLAB code
(fuel-optimal low-thrust spiral, RK4), and
github.com/rtfisher/circular_restricted_three_body_problem. Jon: "a fairly
realistic attempt at representing this in a 2D flat plane". Built in steps, each
seen on a page before it touches the game.*

1. **A mock page** (alongside Phase 10). The same transfer drawn three ways:
   - today's flight;
   - a smooth arc, time-scaled so it is fast through the middle and slow at
     departure and capture;
   - the same arc arriving on a chosen side of the planet.

   Plus one gravity assist past a big planet. Jon picks what reads best in 2D.
2. **Transfer arcs and arrival side** (days). The autopilot flies a real arc.
   The ship can capture on the front, back, lit or dark side of a world, and
   orbit with or against its spin, at about the same cost (Jeremy: "since
   you're already in orbit the energy should be virtually the same").
3. **Gravity assists** (days). Where a big planet lies along the route, the
   autopilot may swing past it. In the planet's frame the ship leaves at the
   speed it came in; in the system's frame it gains or loses speed and turns.
   It pays in fuel or time, and the path shows the swing.
4. **Two engine systems, visible.** An ion drive inside a system (blue flame,
   Phase 10) and the jump drive between stars, which looks and sounds different
   (Jeremy: "it only makes sense with two separate engine systems").
5. **Prototype: two-star and big-Jovian systems** with restricted three-body
   navigation: low-energy paths along the gravity of two bodies, tested in a
   page first. The most distinctive and the riskiest step; it ships only if the
   prototype reads well at the game's scale.

Constraints: `ShipFlight` owns the flight; co-op partner positions
(`Net.report_spot`, sent as offsets from the orbited world) must keep working;
the path must stay smooth at the game's pixel scale.

**Gate:** Jon picks each step from its page; partners still fly where they are
on a co-op map; fuel per route is measured before and after, so assists do not
quietly break the fuel economy.

### Phase 14 — Words that don't read as AI
*Cody: "feels very AI", for example "We can't jump there yet. The button says
why." Depends on the alpha ending, so the list is complete.*

Collect the flagged lines during the alpha. Rewrite each to state the concrete
fact, for example "Too deep. One ring at a time." Re-record the voiced ones, at
about 0.4 credits a character. The recorder now refuses all-caps words in a
spoken script, since eleven_v3 spells them out.

**Gate:** every flagged line rewritten, and every voiced one re-recorded or its
text matched to its take.

### Phase 15 — Riding the galaxy (design only)
*Jeremy: instead of a shrinking-ring kind of pressure, let the run ride the
galaxy's rotation. "You're fighting the angular momentum of the galaxy spiral
with your jump drive and then riding the currents of the solar system with your
orbital mechanics."*

A different answer to what pushes a run forward: jumps with the spiral's turn
are cheap, jumps against it are dear, and the map slowly turns under the run.
It reaches the jump rule, fuel, the chart and the core's place, so it is a
design page of options first, decided after the alpha data and Phase 11. No
build is planned yet.

**Gate:** a page of options and Jon's ruling (ruled Oct 27: a design page later).

### Loose ends

- **Set bonus texts that do not match the code.** Cygnet 5, Verity 5 and
  Calyx 5 by the Oct 17 finding; `CHANGELOG.md`'s 0.1.0 known issues name
  Cygnet 5, Korvan 3 and Solari 3. Parked until after the alpha (Jon, Oct 18).
- **Co-op:** two ships starting different fights in one system in the same
  second can mismatch. Rare; left as it is.

## 3. Running alongside

**The balance spine.** `HeadlessSim` is the only thing in this project
that answers "is this playable" without a human playing it. Every phase
that touches the economy re-runs it: 3, 5 and 6 before, and 11 next. It once
found a 22.5% stranded regression that no amount of reading would have. Since
Oct 22 it also flies the run-length study and prints what going deep pays.

**The playtest is the other half.** The sim models a competent player.
Kevin's run (Oct 22) and the friends' alpha (Oct 22 and 23) are where the
balance, tutorial and co-op work of 0.4.0 to 0.4.2 came from. Ask for the zip
from SAVE MY LOGS with every report.

**The measurement habit.** Four separate multi-round debugging loops in the
session that wrote this plan were resolved by instrumenting and measuring,
after reasoning had failed. Applies equally here: before tuning the economy,
print the distributions.

---

## 4. Open rulings

Each needs a human decision. Rows 1, 1b, 3, 7 and 8 are settled and were
removed; see the footnote. Rows 5, 9, 10, 12, 13, 15 and 16 were ruled on Oct 27 and moved to the table below.

| # | Ruling | From | Blocks |
|---|---|---|---|
| 4 | Three reds. `UITheme` now names `LEAVE` for exits and `WARN`/`BAD` for warnings; the older literal sites were left alone on purpose | B3 | Nothing now; a sweep of the literals |
| 14 | Which health and damage change, after the study | Phase 11 step 1 | Phase 11 steps 2 to 5, Phase 12 |

### Ruled since Oct 20

Jon's rulings since the last pass, with where each landed. Read them before
changing how anything they touch plays.

| Ruling | Jon's words | Where |
|---|---|---|
| Other five manufacturers (ruling 5) | After the alpha; the chain stays Korvan then Solari for the friends' alpha | Oct 27; the plan |
| Unique art (ruling 9) | "Unique cards AND modules get their own art ALWAYS. I have a lot of PixelLab credits." No borrowed pictures | Oct 27; the plan |
| Criticals (ruling 10) | No critical hits | Oct 27; the plan |
| Chassis hull against pips (ruling 12) | C: show the real hull beside the pips; the tooltip says a pip is about 7 hull, rounded | Oct 27; Phase 10 |
| Too-deep stars (ruling 13) | A: dim stars in reach that are too deep | Oct 27; Phase 10 |
| Jump rule (ruling 15) | Two rings deeper per jump, now (was one). Re-tune after | Oct 27; Phase 10 |
| Riding the galaxy (ruling 16) | A design page later, after the alpha data and the combat study | Oct 27; Phase 15 |
| LOCAL while docked | Greyed out with "Docked. Press UNDOCK to leave."; UNDOCK is the only way out | Oct 27; Phase 10 |
| A jump goes one ring deeper at most | "A1D ... I want this to be a hard game" (Oct 22) | b28fdad6, 0.4.0 |
| The Custodian has 200 hull | "custodian health at 200" (Oct 22) | b28fdad6, 0.4.0 |
| The Custodian loses Plated Up; Annihilate deals 40 | "Option 1" (Oct 22) | 7790b9f5, 0.4.0 |
| No commons from danger 5 in | a hard game where going deep is worth it (Oct 22) | 27d7f6eb, 0.4.0 |
| The ARCHIVE is removed | a cool idea, but not for a procedural game (Oct 22) | 551ef568, 0.4.0 |
| A.S.H. cannot be clicked away | "Can we soft lock the screen so A.S.H. can't be dismissed?" (Oct 22) | b54214f1, 0.4.0 |
| The deep tutorial, all of it, voiced | "Tutorial: scope:all voice:record bugs:fix" (Oct 22) | 5c221f81, 0.4.0 |
| The quest log is a QUESTS tab, with no count on it | "I chose A, the JOBS tab" (Oct 22) | 21017bc8, 0.4.0 |
| The Hellbender's posters carry no bounty | the bounty was promised and never paid (Oct 22) | 170bb67d, 0.4.0 |
| LOCAL and GO open the same thing | "Clicking GO or clicking LOCAL should have the same result" (Oct 21) | 1a16d049, 0.3.2 |
| A full ship stays full across a fit | "a full ship stays full" (Oct 22) | 9bc71393, 0.4.2 |
| Ship pictures show weapons only | from Geno: a less messy ship (Oct 23) | 2c75081b, 0.4.2 |
| Lock on stacks | Jon's own play, no words recorded (Oct 23) | aecebc51, 0.4.2 |
| A.S.H. says a line aloud once; COMMS keeps them | from Jeremy: "Give me an option to revisit all communications" (Oct 23) | 9e1e58cf, 0.4.2 |

---

*Rows 2 (card dimensions) and 6 (hull 0 to 6 mapping) were dropped on Aug 24:
the first is settled in `CardView.gd`, the second cites a section of a document
that was never landed. Row 11 moved to `coop-design.md` §16.*

*Rows dropped on Oct 23. Row 1 (run-state flags): the option system carries run
state instead of a flag store, per `docs/briefs/ENCOUNTER_GENERATION.md`, and
event quests are built on it (0.4.1). Row 1b (EVT-092): it was never authored,
and the batch it blocked was written another way (Phase 8). Row 3 (the palette):
B3 is dead. Row 7 (the met-threshold tier): meeting a check is its own band, MET,
with no roll (`SkillCheck`). Row 8 (the hard gate ratio): hard gates are only for
meter payments and physical impossibility (`docs/briefs/ENCOUNTER_AUTHORING.md`),
and an unaffordable one greys and says by how much (`ENCOUNTER_FLOW.md`
ruling 8).*

*Phase 9's citation to `manufacturer-identity.md` §2 is struck. The header
already lists that file among the three source documents that were never
landed. The phase then cited a SECTION of it anyway, which is what made it
read as a spec somebody could go and consult. Phase 9's own paragraph carried
the whole spec, so nothing was lost with it.*
