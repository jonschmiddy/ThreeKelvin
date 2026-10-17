# Handoff: merging `claude/festive-rubin-hd2567` into `main`

**For the Claude Code session in VS Code that merges this branch.** Written
2026-10-15 by the cloud session that built it. Read this, then
`tkg/CLAUDE.md`. Once the merge is done, move this file to `docs/archive/`.

Jon's merge rule still holds: **main only moves on a full gate pass**
(`.github/scripts/validate.sh`). Nothing on this branch reverses a ruling in
`tkg/CLAUDE.md`.

---

## The state of the branch

- 82 commits on top of `a6976ef` ("Worker threads do pure CPU work only..."),
  which was `origin/main` when this was written. If `origin/main` has not
  moved since, this is a **fast-forward**.
- Last full gate run in the cloud: **PASSED** on `8556415` (Oct 17), after
  every change on this branch (Solari's hulls, grades, lights, parts, cards
  and art). The run before it failed only the retired-vocabulary check
  (one retired word in comments and this file), fixed in that commit. **Run the
  gate yourself before merging, whatever this says.**
- The cloud container was slow. Two tests were timing-sensitive there and
  were fixed (see "Gate changes"). On Jon's machine the gate should take less
  time than it did there (26 to 45 minutes).

## How to merge

```bash
git fetch origin
git switch main && git pull                     # Jon's local main may have work the cloud never saw
git log --oneline main..origin/claude/festive-rubin-hd2567 | wc -l   # 29 (more if work landed after this was written)
git merge-base main origin/claude/festive-rubin-hd2567               # a6976ef... if main has not moved
```

**If main has not moved** (the merge base is `main`'s tip):

```bash
git switch claude/festive-rubin-hd2567 && git pull
cd tkg && godot --headless --path . --import    # REQUIRED: new class_name HullGrade
cd .. && .github/scripts/validate.sh            # must end VALIDATION PASSED
git switch main && git merge --ff-only claude/festive-rubin-hd2567
git push origin main
```

**If main has moved:** merge main INTO the branch first (a merge commit, never a
rebase or force-push), resolve, run `--import`, run the gate there, then
fast-forward main. Where a conflict is likely:

- `tkg/CLAUDE.md`: this branch added rows to the harness table (GradeSheet,
  GradeLocal, WreckSiteTest, BandDropTest, IdleSoundTest) and extended the
  systemtest row. Keep both sides' rows.
- `.github/scripts/validate.sh`: this branch added steps (see "Gate changes").
  Keep both sides' steps.
- `tkg/scripts/systems/SaveGame.gd`: **this branch bumped `VERSION` to 33.**
  If main bumped it too, renumber one side and keep both notes, oldest first.
  `OLDEST_READ` stays 29.
- `tkg/scripts/autoload/Database.gd` (`GRADE_BASE`, `hull_art_name`),
  `SectorScreen.gd`, `EncounterView.gd`, `Router.gd`, `SystemLayout.gd`,
  `SystemPanel.gd`: all touched here, so read both sides before resolving.

After the merge, Jon looks at it by eye in the real game on Windows (the cloud
had no GPU window, only Xvfb). See "Look at it in the game".

---

## What the branch does (newest last)

**Housekeeping**
- `81e2088` The map's fabric grid waits for its worker jobs on exit (stowtest
  hung 5 times in 6 at quit without this). CI `timeout-minutes` 25 to 40.
- `856b285` ROADMAP brought up to October.
- `b942c66` The idle engine bed is heard on the refit and transfer screens
  (`hums = true`). New gate step `IdleSoundTest`.

**Fights and LOCAL**
- `f419937` When a fight opens on LOCAL over wrecks, the wrecks leave the
  picture (`EncounterView.hand_wrecks` / `wrecks_out` / `WRECK_EXIT`), handed
  across the screen swap in `Router.start_combat`. **Jon never picked the look:
  it is A (fade). B (drift) and C (recede) exist.** The event band drops by
  sliding, eased (Jon's pick), and the bar under the view eases up only once
  the band has gone. New gate step `BandDropTest`.
- `553fbbc` Enemy engine flames start at their own sterns when a pack is drawn
  from half sheets (`ThrusterFx.for_picture(..., half)`).

**Hull grading** (Jon: "one hull per weight, graded C to S by code"; he picked
**AB+DEF**)
- `HullGrade.gd` (new, `class_name`) bakes a grade onto one sprite:
  - wear (A) and paint (B): the manufacturer's band colour always stays at C;
  - markings (D): a registry number painted on the hull, tone on tone
    (Jon picked look A: one ink, the hull's grey `HullGrade.REG_LIFT`, a fifth, lighter
    than the average of the panel under the number), plus chevrons at S;
  - live lights (E): an additive layer that flickers like aircraft lights,
    drawn by `ShipView`;
  - kit (F): removes thin fittings toward C and never draws anything at S.
- Placements are hand-set in `tkg/art/hull_grade.json` (registry, chevrons,
  windows on the hull's own glass, nav lights, beacon, surface and tip
  markers). The export presets already ship `*.json`.
- `DB.GRADE_BASE = {light: c, medium: a, heavy: a}`. Jon picked **L1** (today's
  light C) and **H3** (today's heavy A). Every grade of a weight draws, mounts
  and burns from that one picture.
- Every hull's band is put onto the medium's amber (`HullGrade._band`).
  Every C band wears through in soft patches rather than a pixel checker
  (Jon asked for this on all C tiers).
- Palette lock: a bake may use only the sprite's own colours plus the band
  ramp. Gate step `GradeSheet`, for all three weights.
- `GradeLocal` (needs a window) films a graded hull parked on LOCAL.

**Wrecks, places and SECTOR LOOT** (Jon: "each planet or POI you can visit
should contain its own wrecks/fights")
- `e14bed1` Each wreck records where it died (`Jetsam.site`: the body your ship
  orbited, -1 the star, -9 open space). LOCAL draws only the wrecks at the
  place you are parked (`Run.wrecks_here`). A wreck keeps its death look and
  fight marks by its number among the whole system's wrecks
  (`Run.wreck_ordinal`).
- `8b11c35` SECTOR LOOT shows the system's pile **plus what is left in every
  wreck you have opened** (`Jetsam.opened`, `Run.sector_loot`, `MapGen.PileView`).
  It is a view: each item is still claimed in its own container, so co-op
  claims are unchanged. A part dropped into SECTOR LOOT goes on the pile; a part
  dropped into an open wreck stays in that wreck, and SECTOR LOOT shows it.
- `9b2bb57` One place, one fight:
  - **One event per world**: a planet, the gas giant and the star each hold one
    event at most (Jon: "That should be a rule"). A belt still holds several.
  - The Hellbender gets its own contact past every orbit, added last so no
    other body moves.
  - The Hellbender and the core's Custodian are engaged only when parked at
    their place. LOCAL anywhere else says to fly out, and its button opens the
    map.
  - A jump now arrives at the system's edge (`Router._on_jumped` clears
    `SystemMapScreen._parked` for that system), so an arrival ambush leaves its
    wrecks at the edge.
  - Bots (`BotPilot`) still call `Router.engage_here` directly from anywhere.
    That is deliberate.

**Saves**: `SaveGame.VERSION` 32 to 33. A wreck saves `site` and `opened`. A
32 save's wrecks read as `MapGen.SITE_ANY` (they show at every place, as
before) and `opened` falls back to `scanned`. Removing planet sharing changes
system layouts, so a save parked at body *k* may come back orbiting a
different body. That is harmless before the alpha ships.

## Gate changes on this branch

- New steps: `IdleSoundTest`, `BandDropTest`, `GradeSheet` (light, medium,
  heavy), `WreckSiteTest`. `systemtest` gained the one-event-per-world and
  Hellbender-place checks.
- `FightCountTest` limit raised from 240 to 480 s. On the slow container its
  168 fights took about 310 s on main as well as here. The limit only stops a
  hang; it checks nothing.
- `KillHoldTest` now holds the breakup to the ship's resting place this frame
  *or last frame* (it takes the bob a frame late). On a slow machine a frame
  moved the bob 2 px and failed it, on main too. A misplaced breakup (14 px)
  still fails.
- CI `timeout-minutes` is 40.

## Look at it in the game (Jon, on Windows, after the gate)

1. The chassis select and a new run at each weight: the graded hulls, with
   lights flickering at A and S and the band in amber.
2. `godot --path . -- ship` then the yard (`-- station`): graded hulls on the
   stands. `YardSeatTest` passed, but nobody has looked at the yard by eye.
3. A system: fight an event, fly to another planet (no wrecks there), fly back
   (wrecks there). Open a wreck, leave something in it, and check that SECTOR
   LOOT shows it from elsewhere in the system.
4. The core: arrive (at the edge, the drawer says fly out), fly to the
   Custodian on the map, ENGAGE.
5. A Hellbender system (`-- sheet=SystemShot node=hellbender out=x.png`
   photographs its map): its contact past the last orbit, ENGAGE there.

## Open, for Jon to decide (do not decide for him)

- The wreck exit look: A fade (current), B drift, C recede.
- Whether a belt should also hold only one event.
- The SECTOR LOOT pile itself stays system-wide. Jon was told this and did not
  ask for it to change.
- Other manufacturers' graded hulls come after the alpha. Korvan only for now.
  `HullGrade.key_for` assumes `korvan/`, which is right while every
  manufacturer shares the Korvan sprites.

## Hull names (Jon, Oct 15)

One name a weight, the same at every grade, and ONE word: no class word after
it ("get rid of the second word for each ship"). `MANUFACTURER_HULLS[m].names`
in `Database.gd`, light, medium, heavy:

| Manufacturer | Light | Medium | Heavy |
|---|---|---|---|
| Korvan | Hammer | Anvil | Foundry |
| Solari | Flare | Prominence | Nova |
| Probate | Picker | Wrecker | Breaker |
| Redline | Ghostlight | Moonrunner | Blackout |
| Cygnet | Raven | Murder | Nightfall |
| Verity | Heirloom | Endowment | Inheritance |
| Calyx | Sapling | Copse | Vivarium |

`CLASS_NAMES` / `hull_class()` stay authored and are now shown nowhere: the
party screen and the fight's party strip print the weight instead ("change to
light medium heavy"). A card is also called Flare; Jon was told. Picked on
https://claude.ai/artifact/VkfSxfDsZiTBTGMJHiy1xq (its db holds the picks and
Jon's notes).

## Templates for the other manufacturers' hulls

`tkg/art/tools/hull_template.py` writes a block-in and a code guide for each of
the 18 sprites (six manufacturers, three weights) into `tkg/art/hull_templates/`
(`.gdignore`, so they are never imported). Page:
https://claude.ai/artifact/QnBxTyEYJ3ywNK35RWYSvZ . The manufacturer plan
(https://claude.ai/artifact/7p4xze2tuQ2FAQ6MbTkMe7) now plans three sprites a
manufacturer. Nothing here touches the game.

## Solari's hull sprites (Jon, Oct 15), done but not flown

Solari is amber on white heat-shield now (`Database` manufacturer row: mark
`#ef9f27`, field `#f2eee6`; the BoardScreen heat-lamp ad to match). Jon: "they
look almost identical to the design language as korvan", so the hull is white
tile, not steel.

- **Templates.** `hull_template.py`'s Solari spec: white `tile` plate, brass
  reactor rings, the radiator crest on the spine and a blade keel under the
  belly (both drawn before the hull, so they sit on it), engine bells on the
  stern face. `palette_solari.png` is built from the templates' colours.
- **Sprites.** PixelLab pixflux, the template as the init image and the palette
  as the colour lock, 5 takes a weight. Jon picked light A, medium E, heavy A;
  `tools/hull_clean.py` cleaned them (off-silhouette pixels, saturated specks on
  tile, islands) and they were hand-fixed where Jon pointed (the third ring's
  slot, the noses). Raw takes in `art/hull_templates/picked/raw/`, the picks in
  `picked/`, and the game copies at `art/sprites/hulls/solari/hull_<w>_a.png`.
- **Grades.** `HullGrade` bakes them C to S like Korvan (`_manufacturer` picks the
  registry letter, S; non-Korvan manufacturers keep cool colours out of the ramps,
  which fixed blue flecks). `key_for` reads the manufacturer from the sprite's folder.
  Placements in `art/hull_grade.json` under `solari/hull_<w>_a`.
- **Lights (Jon: "The light positioning makes NO SENSE").** Each brass ring's
  slot is one lit strip and nothing else is lit but the white nose light. The
  strips are windows tagged `pulse`: they swell and ease in turn, back to front
  (Jon: "BACK to front"), one wave every 2.4 s (`HullGrade.level`). The middle
  ring lights at B, two at A, all at S.
- **Not wired into play.** `DB.hull_sprite` still hardcodes the Korvan folder,
  so a Solari ship in a run wears Korvan art. `-- sheet=GradeLocal manufacturer=solari
  weight=<w> grade=<0..3>` films one parked on LOCAL with its parts and flame
  off. Still to do for play: the sprite path by manufacturer, mounts
  (`anchors.py`), `engines.json`, then `-- mounts`, MouthSize, YardSeatTest.
- **Pages:** grades https://claude.ai/artifact/4vWHrp4oD4cBhRhqHZEAxT (in game),
  lights https://claude.ai/artifact/X7aMxAimjbMh9b7tdmzHhV (the pick).
- The other five manufacturers: same pipeline, not started. **Ask Jon before
  spending PixelLab credits, every time, with takes and a cap.**

## Solari's modules and cards (Jon, Oct 15)

Jon: "Then work on the modules and cards." Built from the manufacturer plan's
Solari tab (https://claude.ai/artifact/7p4xze2tuQ2FAQ6MbTkMe7). Page with every
Solari card as the game draws it: https://claude.ai/artifact/1tL4AXkZBhPL45XwXA4JNf

- **18 new parts** in `Database.gd` under the Solari section: Solari is 25
  parts and 39 unique cards of 40 (`-- content`). Not in the loot pool:
  `ACTIVE_MANUFACTURERS` is still Korvan alone, so nothing changes for a
  Korvan run.
- **Flashpoint**, a new card field and keyword: +N damage per hit if heat is
  over capacity when the card resolves. `CardData` (field, text, glossary,
  `pyre` glyph), `CardResolver`, `Combat.card_output` / `card_hot`, `Policy`,
  and the manifest's scorer. Jon: "As planned" (Sparkfall common, Overpressure
  and Flashover epic).
- **Starter:** Solari starts on the common Ember Lance (Jon). The Plasma Lance
  is now a find.
- **Names:** the heliostat's capstone is Sunburst and the Sunheart's is
  Photosphere, not Nova and Prominence, which are hull names (Jon: rename).
- **Fixed:** Thermal Purge vented before it read your heat, so it hit for 2
  while its face said heat + 2. `vent_all` now resolves after everything that
  reads heat. The brace-from-heat log names the card, not "Shroud".
- **Gates (HoldTest):** "Solari attacks run hot" and "Solari heat is never
  waste", both passing. The rarity law now PRINTS a warning for a pair on a 1-2
  cell part above common (13 parts across five manufacturers), not yet a failure.
- **Korvan is the generalist; the other six grant their own cards** (Jon's
  ruling, written into `docs/catalogue.md` §6 and CLAUDE.md's rulings). A
  shared card only where the manufacturer's own would be the plain card
  recoloured ("Let's just have it be the unbranded card").
- **The four Solari pairs are fixed** under it: Overdrive + Open the Throttle,
  Heat Shroud + Bolt On, Flare Rack + Range, Cauterising Torch + Patch. Solari
  is 40 of 40 unique cards. Nine pairs on other manufacturers still warn.
- A card that decommissions itself now prints **Decommission** (Jon), not
  "Decommissions itself": Sunburst and Solstice.
- Checked: holdtest, attrtest, reactor, content, glyphs, savetest, an import
  compile. Not run: the sim (Solari does not drop, so a Korvan sim cannot see
  it) or the whole gate.

## Solari's card art (Jon, Oct 16), all 40 done

Every Solari card has a picture in `tkg/art/sprites/cards/` (`-- artcheck`:
116 cards drawn, 0 on glyphs). Made with PixelLab's pro model
(`generate-image-v2`, 92x60, a 46x30 style reference per prompt, 10
generations a call, 9 takes), posted with `tools/card_batch.py --post <in>
<out> solari` (the Solari tile ramp joins both snap pools, or the cream comes
out gold), installed with `--install`.

What worked, after three rejected rounds of one shared composition (close-up,
ship-in-the-void, impact): **bespoke prompts per card**, two ideas a card,
every take shown, Jon picking per card; then fresh ideas for the misses, and
for the last few, a one-line reading of each card agreed with Jon BEFORE any
prompt was written ("they just fundamentally misunderstand the cards").
Glowshot was the first Solari picture and is the void-ship reference. Raw
takes and prompts are in `tools/out/solari/` (gitignored, local to the cloud
session).

`ArtCheck.MANUFACTURERS` now includes Solari, so its 25 modules show as
"still procedural" (missing art is the designed fallback, not a failure).

**Modules: 12 of 25 in (Oct 16).** Jon's picks from the dark-steel round,
installed in `tkg/art/sprites/modules/`: Bellows Pump, Cauterising Torch
(flipped), Ember Lance (flipped), Firebrick Lining, Foundry Bus, Heat Bank,
Overdrive Coils, Overpressure Cannon, Heat Shroud, Spark Thrower, Sunspot
Mortar (flipped) and Thermal Purge Cannon. Each is rescaled to fill its box
with `tools/scale_to_box.py` (artcheck: all at size). Still procedural, Jon
said none: Annealing Lamp, Bleed Valve, Smelting Crucible, Flare Rack, Heat
Haze Projector, Heliograph, Heliostat Lance, Incinerator Hatch, Solstice Mirror
Array, Plasma Lance, Radiator Sail, Star Furnace, Sunheart Core. Page:
https://claude.ai/artifact/3LSjHdDaAQTCh1TMZMUmLD (picks and flips in its db,
`picks/solari_modules2`). Prompts and roll script: `tools/briefs/solari_modules.json`,
`tools/briefs/solari_modules_roll.py`; every take in `tools/briefs/solari_module_takes/`.
The last 13 had a fresh round (Jon, Oct 16: "none of these are good"; all 13
still procedural, pick up here next session): https://claude.ai/artifact/Xx8bubveSobnW3RWPaqzzs
(picks in its db, `picks/solari_modules3`; takes in
`tools/briefs/solari_module_takes3/`, script `tools/briefs/solari_modules_roll3.py`;
A/B/C/D map to files `<id>_1..4.png`).
Lesson: generate at the slot's shape (a full-box silhouette under the prompt at init strength about 40; at 70 it draws grey boxes),
or the generator draws the part small and thin.

## Where to pick up (Oct 17)

- **Solari modules:** 12 of 25 have art. The other 13 (Annealing Lamp, Bleed
  Valve, Smelting Crucible, Flare Rack, Heat Haze Projector, Heliograph,
  Heliostat Lance, Incinerator Hatch, Solstice Mirror Array, Plasma Lance,
  Radiator Sail, Star Furnace, Sunheart Core) failed three rounds. Next time,
  agree each part's one-line reading with Jon first, as the cards needed, and
  consider the pro model with an accepted Korvan or Solari module as the
  style reference rather than pixflux.
- **Solari cards:** all 40 done.
- **Solari is not wired into play yet:** hull sprite path by manufacturer,
  mounts, engines; and Solari is not in `ACTIVE_MANUFACTURERS`, so its parts
  do not drop.
- **The full gate passed** on `8556415` (Oct 17). Run it again before merging.
- PixelLab: about 2,850 generations left this cycle; it refills Oct 17.

## A.S.H., the ship's AI (Jon and Ashlee, Oct 17), design only

Ashlee's idea: the player needs someone alive to connect to. A.S.H.
(Autonomous Systems Handler) is the ship's AI, named for her: dry, humorous and
teasing, with a holographic face. Brief in `docs/ash.md`, a ruling in
CLAUDE.md ("A.S.H. is the ship, not crew"). Forty draft lines in
`docs/ash_lines_draft.json`, on a keep/cut page:
https://claude.ai/artifact/32V82WK5AkWDfHvp4ccPGs (choices in its db,
`picks/ash_lines`). Jon and Ashlee kept 30 over two rounds (in `docs/ash_lines.json`;
round two: https://claude.ai/artifact/Mtjy8qhcNYP4YLALGFnAPJ). Ruling: no lines
after the ship is lost; she goes with it. Portrait plan in `docs/ash.md` ("Making the
portrait"): pick a calm face from three looks, then edit it into her moods.
Step 1 done: 48 takes (cyan, white-blue wireframe, amber; 64x64) in
`tools/briefs/ash_face_takes/`, pick page
https://claude.ai/artifact/CSvS3545RvS8shquZpCr7Y (`picks/ash_face`). Jon: "just the head. No shoulders." Round two,
head only, in `tools/briefs/ash_face_takes/round2/`, page
https://claude.ai/artifact/EyVuPQbPzfRm2Zxxo9RuqL (`picks/ash_face2`). Jon picked **B15** (`round2/B_15.png`). 32 variations of
B15 (V1 calm, V2 almost-smile with one eyebrow up; 2 pro calls, 20 generations)
in `tools/briefs/ash_face_takes/variations/`, page
https://claude.ai/artifact/VEysnjLHtDkNYZNoYPDX4m (`picks/ash_face3`, any number
of picks). Talking mock-up (free, hand-drawn on B15: mouth closed/slight/open/round,
each with a blink; mouth follows the letters as a line types out, plus hologram
row glitches) in `tools/briefs/ash_face_takes/talk/`, page
https://claude.ai/artifact/JUTcAc8SVhsDiWbd4SmtNd. Nothing in the game yet. Next: her moods edited from the picked face
(ask Jon before spending PixelLab credits), then a portrait slot on LOCAL and her
lines in the log, driven by heat and hull.

## Pages Jon judged this on

- The three graded hulls, all 12 ships: https://claude.ai/artifact/EE7Y4JKuiVY9igCZQ7r1qZ
- Light and heavy base pick: https://claude.ai/artifact/1AM32H9vvcQUYcT4gnBfzm
- The medium in the game: https://claude.ai/artifact/PHGw4DtDVU4x8qj3BYCBDX

## Jon's working rules (from his own handoff)

- Show, don't describe. Pick pages use films or stills at 2x game scale, with
  lettered options, and nothing merges until Jon picks.
- Never spend PixelLab or ElevenLabs credits without asking first, giving the
  number of takes and a cap.
- Replies are short and plain.
- The alpha freezes the morning of **Oct 21**, and friends get it on **Oct 23**.
