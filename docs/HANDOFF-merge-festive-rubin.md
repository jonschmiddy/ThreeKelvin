# Handoff: merging `claude/festive-rubin-hd2567` into `main`

**For the Claude Code session in VS Code that merges this branch.** Written
2026-10-15 by the cloud session that built it. Read this, then
`tkg/CLAUDE.md`. Once the merge is done, move this file to `docs/archive/`.

Jon's merge rule still holds: **main only moves on a full gate pass**
(`.github/scripts/validate.sh`). Nothing on this branch reverses a ruling in
`tkg/CLAUDE.md`.

---

## The state of the branch

- 27 commits on top of `a6976ef` ("Worker threads do pure CPU work only..."),
  which was `origin/main` when this was written. `origin/main` had not moved
  since, so as pushed this is a **fast-forward**.
- Last full gate run in the cloud: **PASSED** on `9b2bb57` (one event per world
  and the Hellbender's place). The two commits after it are this handoff and
  the registry look, which Jon then picked (A, tone on tone; `reg_look` is
  `&"A"`). GradeSheet passed on all three weights with it. **Run the gate yourself before merging, whatever this says.**
- The cloud container was slow. Two tests were timing-sensitive there and
  were fixed (see "Gate changes"). On Jon's machine the gate should take less
  time than it did there (26 to 45 minutes).

## How to merge

```bash
git fetch origin
git switch main && git pull                     # Jon's local main may have work the cloud never saw
git log --oneline main..origin/claude/festive-rubin-hd2567 | wc -l   # 27 (more if work landed after this was written)
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
