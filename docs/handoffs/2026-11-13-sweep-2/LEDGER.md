# Sweep 2 ledger: every finding and where it stands

A copy of the sweep's working ledger, made Nov 14 2026. The reviewers' full reports (the ids below point into them) are not in the repository; James has them.
Statuses: **done**, **part** (see note), **running**, **backlog**, **owner** (for Jon to rule on), **reported** (told, not fixed, on purpose), **dropped**.

## Waves

| Wave | Branch | Theme | State | PR | Evidence |
| --- | --- | --- | --- | --- | --- |
| W1 | cleanup/w1-dead-code | Code nothing calls is deleted; comments that contradicted the code are fixed (2,043 lines out of 111 files) | PR open | #74 | battery 58/58 pass; seeded sim identical; code review: 0 bugs, 10 leftovers fixed |
| W2 | cleanup/w2-tests | The test suite tells the truth: checks that could not fail, the doubled gate unit, the battery's exit code, missing test-map rows | PR open | #75 | stacked on W1; battery 58/58 pass with its own fixed script; code review: 8 findings fixed |
| W7 | cleanup/w7-public-names | 46 private methods that other files call get public names | PR open | #77 | rename map reversed over the diff: 770 lines, 0 unexplained; seeded sim identical |
| W8 | cleanup/w8-layering | Run state and rules helpers leave screen code; the pilot model leaves the test folder | PR open | #78 | step 1 a pure rename (137 lines, 0 unexplained); 34 functions moved, 0 edited |
| W3 | cleanup/w3-yard | Shipyard code lives in the file its name promises | PR open; windowed pixel check owed (YardPerfShot, stationshot) | #79 | moved bodies verbatim; the reshaped functions (walk_off, YardCity.setup/draw, the stand statics) compared with their originals line for line; YardLife 1,826 to 1,478, YardScene 1,401 to 1,278 |
| W5 | cleanup/w5-breakup | ShipBreakup under the file cap (3,639 to 2,886): one hull-picture function, boss plan and creatures in their own files | PR open; windowed pixel check owed (GoldenFrames breakup,hitfx) | #80 | 16 bodies moved verbatim; split boss-plan functions re-inline to the original line for line |
| W6 | cleanup/w6-subject | LocalSubject (3,167 lines) becomes planner, masks and node (1,767 / 917 / 496) | PR open | #81 | 60 bodies moved, 0 edited; staging plan identical for 39,798 plans (implementer's throwaway dump) |
| W4a | cleanup/w4a-flightsolve | FlightSolve under the file cap: two-leg planner and pure math in their own files | PR open (flight and solver tests on the merged stack: all pass, totals identical to the untouched tree) | #83 |  |
| W4b | cleanup/w4b-shipflight | ShipFlight under the file cap: curve math and the old planner out | PR open: step 1 only (curve math to FlightCurves, 4,386 to 4,150 lines); step 2 (the old planner) not done: a pass flag leaks between calls, see the owner list | #84 |  |
| LAG | fix/deck-ride-lag | Jon's report (Nov 13): lag when changing floors in the station | PR open against main (branch fix/station-first-ride; fix/deck-ride-lag was the working branch); windowed checks owed; two small visible changes for Jon to rule on | #82 | DeckRideBench (headless): first visit to the Promenade costs 30 ms and to the Exchange 49 ms in one frame (median of 5); later visits 1.5-3 ms; cause is ShopScene loading its room on first draw. Predates the Nov 9 sweep. GPU side unmeasured. |
| CI | fix/ci-jumpshadertest | CI red on main since Nov 11: jumpshadertest is too slow on the runner's software renderer (about 80 s a film, 11 films, 600 s limit); run it at 960x540 under xvfb | PR open and GREEN on all four parts (after both fixes): jumpshadertest runs alone at --fixed-fps 15 on CI (3:16, limit 400 s); four limits that were under twice their CI time raised (stationdecktest 240 -> 480 was killed once at 242 s; flighthand, wrecksitetest, laddertest) | #76 | logs: all 27 shaders compile, films play with 0 errors, 6-7 of 11 finish before the kill; never passed on CI |
| GUARD | guard/fast-checks | Guardrails for Jon: fast pre-commit checks, tests-for-a-change, new ratchets, guidance for his Claude | PR open (base #73): fast checks, pre-commit hook, check.sh, tests_for.py, three ratchets, Claude hooks, skill, checks table. Reviewed twice (correctness, security); all findings fixed. Untested on Windows and in a live Claude Code session | #85 | static gate 20 units in 6 s; pre-commit 5-7 s; check.sh; tests_for.py; frame_check, tests_map_check, gate_lint; Claude hooks (command guard, edit ratchets, stop reminder; 69-check self-test), finish-a-change skill, checks table in tkg/CLAUDE.md. Untested: Windows, a live Claude Code session firing the hooks. |
| S-A | simplify/hex-consts | Colours parsed once: per-frame Color("#hex") literals become constants (frame_check's to-do list); CommsPanel keeps its PLAY buttons instead of searching the tree every frame | PR open (base #85) | #86 | 6 commits (tip 6b7ad37a), 31 files, 126 new constants plus reuse of 5 existing ones. frame_check baseline 52 entries / 157 calls -> 4 / 10. Orchestrator: each constant put back as its literal and every file compared with the base: 0 code lines unexplained outside CommsPanel (read by hand; the implementer compared the kept list with a fresh search on 17 frames, identical). Implementer: 39 headless rows before and after, same verdicts. Left: SectorScreen (3) and StationScreen (5), which may not grow past their recorded size. No windowed pixel check |
| S-B | simplify/pure-dedupe | Helpers written once: copied pure functions (hashes, brightness steps, colour key, ring points, eases, theme lookup) call one shared definition | PR open (base #86) | #87 | 23 definitions removed in 12 families; shared homes: SkyBake (hash2/noise2/smooth_k), MapGen.hash_cell/hash_unit, FxKit (lv, ring_pixels, ease_out, ease_in_out, ramp_under), UIHash.hash1, HullGrade.key, Widgets.clear, Router.content_theme, SystemView.block_round. Implementer: every pair probed bit for bit (about 40 million tuples, 0 mismatches); seeded sim identical; 52 headless rows before and after, same verdicts. Orchestrator: every removed body read against its shared one: 22 are the same text, 3 differ in form only (a mask that cannot change a 32-bit value; floori vs floorf+int; an int radius widened to float). Review edits: the smoothstep merge reverted (yard and lab files would have preloaded the sky baker for two lines); ramp_under typed Array[Color] (it was Array[Variant], vague in all but name), runtime-probed. code_check baseline 699 -> 697, code_graph 134 -> 132. NebulaWeather's copy of hash_cell removed on the stack tip. Left: LabSavers._oc/_mk (read a member), the excluded eases. FaunaTest is unreliable headless on the untouched base too (crashes with signal 11) |
| S-C | simplify/frame-caches | Work that never changes is done once: exact-key caches (argv, constant tables, name conversions); flight code and redraw-skipping left out | PR open (base #87); battery on this tip 58 of 59 (nettest failed one check under load, passed alone 3 of 3) | #88 | 7 commits (tip 0f50f3cb). Implementer: 33,377 cached-vs-fresh comparisons, 0 mismatches. Orchestrator: every diff read; seeded sim identical to base (sorted, 91 lines); parseall, maptest, rngtest, holdtest, materialtest, BoardSignTest, StationDeckTest, LabSaverTest pass. Two review edits: PixelTurn.turner keeps its allowlist; the cached saver list is read-only. Measured: MaterialTable.by_id 15.8 -> 0.7 ms per 3000 calls; HoldPacking.fits_at 20.8 -> 10.9 ms per 20,000; BoardLamp.level 20.0 -> 6.9 ms per 20,000; LabLogin.savers 3.5 -> 0.3 ms per 2000 (noisy machine). No windowed check of SystemView/NavField/jump |
| W9 | cleanup/w9-code-graph | tools/code_graph.py: the code graph as a repo tool with a gate ratchet | PR open; rebased onto the end of the stack (base #84), baseline regenerated there: 190 entries to 134 | #73 | self-test; red/green on planted violations; code review: 10 extractor bugs fixed; simplify pass applied with report and graph JSON byte-identical |

Landing order: #74 W1, #75 W2, #77 W7, #78 W8, #79 W3, #80 W5, #81 W6, #83 W4a, #84 W4b, #73 W9, #85 guardrails, #86 colours, #87 helpers, #88 done-once (each pre-merged onto the one before). Independent, on main: #76 (CI fix; land first, it turns CI green) and #82 (station lag).

## First review: 161 proposals

By status: backlog 116, done 19, owner 9, part 17

### core

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| core-1 | dead-code | 4 | low | S | **done** | Delete the dead code (Audio flight path, Router derelict path, RunState leftovers) — W1 |
| core-2 | perf | 3 | medium | M | **backlog** | Locate and fix what makes Run.fit_chassis cost 6.6 ms (measure first) |
| core-3 | split-function | 3 | low | S | **backlog** | Split Main._ready along its three seams and read argv once |
| core-4 | split-function | 3 | medium | M | **backlog** | Split Router.start_combat (100 lines, four pieces) |
| core-5 | split-file | 4 | medium | M | **backlog** | Pull A.S.H.'s voice out of Audio into AshVoicePlayer |
| core-6 | dedupe | 2 | low | S | **backlog** | Audio scaffolding that repeats: cached stream load, tape rows, new player |
| core-7 | move-home | 4 | medium | M | **backlog** | Move hull-art resolution and rigging tables out of Database into HullArt |
| core-8 | move-home | 3 | low | M | **done** | Move the parked-ship map off SystemMapScreen — W8 |
| core-9 | split-file | 3 | medium | M | **backlog** | Give RunState's mislabeled 'science' section its real structure, then extract refit |
| core-10 | other | 2 | none | S | **part** | Small corrections: stale comments, widest_hull cache, AffixData imports — W1: the comment fixes; widest_hull cache and AffixData imports not done |
| core-11 | type-returns | 3 | low | M | **backlog** | Typed DockRoute and RefuelOffer for the dock/refuel family |

### systems

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| systems-1 | split-file | 4 | low | M | **done** | Move FlightSolve's two-leg planner and FlightTurn into FlightChain.gd — W4a |
| systems-2 | split-file | 3 | low | S | **done** | Move FlightSolve's pure static math into FlightMath.gd — W4a (FlightSolve 3,969 to 3,614; still over the cap) |
| systems-3 | split-function | 4 | medium | M | **backlog** | Split SaveGame.load_into_run into ordered phase functions and drop the dead Hellbender switch |
| systems-4 | dedupe | 4 | medium | M | **backlog** | SystemLayout: one spelling for job/Hellbender placement, Kepler period, body names, beacons and twin head |
| systems-5 | dedupe | 3 | none | S | **backlog** | One wreck count and one wreck stream key helper |
| systems-6 | dedupe | 3 | low | M | **backlog** | Combat: write soak, foe raising, hail/flee gate and victory tail once |
| systems-7 | split-function | 3 | low | S | **backlog** | CardResolver.resolve: split by effect and share the per-hit damage with Combat.card_output |
| systems-8 | dead-code | 2 | none | S | **part** | Dead code and stale comments sweep — W1: all but HullFit.fitted_cached (file is parked) and the SaveGame Hellbender switch (systems-3) |
| systems-9 | type-returns | 3 | low | M | **backlog** | FlightSolve tidy: typed Best candidate for _b, _ring_at, _reset_best, curved_arc doc |
| systems-10 | split-function | 3 | medium | M | **backlog** | FlightSolve._price: split by phase and name the stride-4 candidate array |
| systems-11 | move-home | 3 | medium | M | **part** | Restore layering: OptionResolve and SkillCheck reach into UI — W8: steps 1 and 3 except bill_rows (it builds theme colours); tone and the signal are for the owner |
| systems-12 | perf | 2 | low | S | **backlog** | Ladder and Unlocks: read run history once per screen, not per call |
| systems-13 | perf | 2 | medium | M | **backlog** | HullGrade: cache light footprints, share run labelling and key/luma, guard empty accent |
| systems-14 | bug | 2 | none | S | **owner** | PlaytestLogs bundle filename drops seconds, so same-minute bundles overwrite — player-visible: PlaytestLogs bundle name drops seconds, so same-minute bundles overwrite |

### net

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| net-1 | dedupe | 4 | low | S | **backlog** | One _forget_party_state() for the four copied reset blocks |
| net-2 | dedupe | 2 | low | S | **backlog** | Spot RPC twins and the magic 7-array |
| net-3 | split-file | 3 | low | M | **backlog** | Move party-clock and flight statics to PartyClock.gd |
| net-4 | split-file | 3 | low | M | **backlog** | Lift pure foe-turn rules into FoeTurn.gd |
| net-5 | type-returns | 3 | medium | L | **backlog** | Typed Flight record (optional, larger) |
| net-6 | untangle | 2 | low | S | **backlog** | Name the SharedFight foe row in one place |
| net-7 | split-function | 2 | low | S | **backlog** | Split BotPilot._fight (62 lines) |
| net-8 | type-returns | 2 | low | S | **backlog** | LobbyCode.parse returns a typed Parsed |
| net-9 | other | 2 | none | S | **part** | Consts to the top, stale comments, tiny tidy — W1: stale comments only; const moves not done |
| net-10 | type-returns | 2 | low | S | **backlog** | HeldAsk record for the hold_asks test seam |
| net-11 | perf | 1 | medium | S | **backlog** | build_of rehashes the whole wire dictionary per call |

### ui-yard

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-yard-1 | dead-code | 2 | none | S | **part** | Delete dead code and fix two small defects — W1: all but the YardSound lambda guard (added, then reverted as new logic in a deletion wave) |
| ui-yard-2 | move-home | 4 | low | S | **done** | Give Banner, SlotPads and mount_ceiling their own files — W3 |
| ui-yard-3 | move-home | 3 | low | S | **done** | Move the undock choreography out of Moored into LocalUndock — W3 |
| ui-yard-4 | split-file | 4 | low | M | **done** | Extract stand geometry from YardScene into YardStands — W3 (caches stay on YardScene; the inline under scan left in place) |
| ui-yard-5 | dedupe | 4 | low | M | **backlog** | One scoring loop for seat_pair and YardSlot.seat, one under-scan, one named _ink |
| ui-yard-6 | type-returns | 4 | medium | L | **backlog** | Declare the placed-ship record (PlacedShip) |
| ui-yard-7 | split-file | 4 | low | M | **done** | Move the city's wall life into YardCity — W3 |
| ui-yard-8 | perf | 4 | low | S | **backlog** | Stop fitting the live Run three extra times per banner click |
| ui-yard-9 | perf | 3 | medium | M | **backlog** | Bake the deck's ship mask in bytes and share the belly shading with the front |
| ui-yard-10 | move-home | 3 | low | S | **done** | ShipLift._walkers belongs to YardLife — W3 (KEY_* constants not added) |
| ui-yard-11 | move-home | 3 | low | S | **done** | YardBand public word() and move hull-mount helpers out of YardInfo — W3 |
| ui-yard-12 | untangle | 3 | low | S | **backlog** | Name the front door's switches and gather its launch-mask state |
| ui-yard-13 | type-returns | 3 | medium | M | **backlog** | Type LiftPlume's lobes and weights and fix its comments |
| ui-yard-14 | split-function | 2 | low | S | **backlog** | Split YardEdge._process into named steps |

### ui-station

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-station-1 | dedupe | 4 | low | M | **backlog** | LabPage base class for LabAugment/LabRecipes |
| ui-station-2 | dedupe | 3 | low | S | **backlog** | LabSavers: one held clock, one owner colour, rename _s3_hold |
| ui-station-3 | untangle | 3 | low | M | **backlog** | StationScreen: hoist all members and consts to the top |
| ui-station-4 | split-file | 4 | medium | L | **backlog** | Extract the hiring-board deck into StationWorkDeck |
| ui-station-5 | split-file | 5 | medium | L | **backlog** | Split LabSavers.gd by owner following LabSaversSolari |
| ui-station-6 | dead-code | 2 | low | S | **part** | Dead-code sweep verified by grep — W1: items 1-9; item 10 (PostingBoard._ticker double paint) needs a pixel check |
| ui-station-7 | untangle | 2 | low | S | **backlog** | LabScene power-on clock accessors replace LabLogin reach-ins |
| ui-station-8 | dedupe | 2 | low | S | **backlog** | TradeCounter: one lit edge and one readout helper |
| ui-station-9 | split-function | 3 | low | M | **backlog** | Board painters: per-piece functions, _pin_pair, FIXED_SIZE table |
| ui-station-10 | split-function | 3 | low | M | **backlog** | Split LabAugment.paint/_caption and LabRecipes.paint |
| ui-station-11 | split-function | 2 | low | S | **backlog** | PostingBoard: split _side, rename TICKER to TICKER_H, share strip ad |
| ui-station-12 | type-returns | 2 | low | S | **backlog** | Typed returns for BoardLamp._bars, ExchangeScene._fleet_list, ShelfDisplay._pack |
| ui-station-13 | bug | 1 | none | S | **backlog** | Two latent defects: rope<=0 loop and modulo-by-zero guard order |
| ui-station-14 | perf | 1 | low | S | **backlog** | LabAugment.paint_live: one bill() per tick instead of per affix |

### ui-local

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-local-1 | dead-code | 4 | none | S | **part** | Dead-code sweep across the area — W1: all but AreaView._core/_pulsar (doc says they stay; see owner list) and WARP_IN_S (a Python tool reads it) |
| ui-local-2 | dead-code | 4 | none | S | **done** | Delete unreachable EventScreen and Router.show_option_at — W1 |
| ui-local-3 | bug | 3 | medium | S | **owner** | Mirrored LOCAL: finish the UiRect sweep (bug) — player-visible bug: mirrored LOCAL, the UiRect sweep is unfinished |
| ui-local-4 | split-file | 5 | medium | L | **backlog** | Extract SectorScreen's zoom-ladder camera into SectorLadder with typed records |
| ui-local-5 | split-file | 5 | low | L | **done** | Split LocalSubject into SubjectPlan, SubjectMask and the node — W6 |
| ui-local-6 | dedupe | 3 | low | S | **backlog** | LocalSubject small dedupes that keep the maths |
| ui-local-7 | untangle | 4 | low | M | **backlog** | Give LocalSky a typed face: NearItem, HandOff and accessors instead of get("_x") |
| ui-local-8 | dead-code | 4 | low | L | **owner** | Retire OutcomeRow's trial looks A, B, C and today (needs Jon's OK), then type changes() — retire OutcomeRow's trial looks A, B, C: needs Jon's OK |
| ui-local-9 | split-function | 3 | low | M | **backlog** | Split LocalEventDrawer._result (after proposal 8) |
| ui-local-10 | split-file | 4 | low | M | **backlog** | Extract EncounterView's pack layout into PackLayout |
| ui-local-11 | type-returns | 3 | none | S | **backlog** | Type EncounterDrawer.option_state, untaken and quiet_lines |
| ui-local-12 | perf | 3 | low | M | **backlog** | Per-frame waste: _Wreck redraw, LocalLife.step, LocalDust bookkeeping, NavField.feed |
| ui-local-13 | bug | 2 | medium | S | **owner** | LocalSky._wx_place band has zero height (bug) — player-visible bug: LocalSky._wx_place band has zero height |
| ui-local-14 | split-file | 3 | medium | M | **backlog** | Extract SectorScreen's death and loss handling into SectorDeath |

### ui-chart

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-chart-1 | dead-code | 4 | low | S | **part** | ZoomLadder: delete dead bar/grab code, one picture-grab helper, shared handoffs — W1: dead bar/grab code; the picture-grab helper and shared handoffs not done |
| ui-chart-2 | split-file | 5 | medium | L | **backlog** | ZoomLadder: lift the calm move into CalmLadder |
| ui-chart-3 | split-function | 3 | low | S | **backlog** | ZoomLadder.preroll: split the 169-line door |
| ui-chart-4 | type-returns | 4 | low | M | **backlog** | MapChart: typed SkyField replaces SKY_FIELDS and get()/set() |
| ui-chart-5 | split-file | 5 | medium | L | **backlog** | MapChart: move the star-field generator to ChartFieldGen |
| ui-chart-6 | move-home | 4 | low | M | **backlog** | StarchartScreen: move Glyph, Crosshair, ChartAhead, MicroGauge and view memory to the chart side |
| ui-chart-7 | move-home | 4 | low | S | **backlog** | ChartSky: move the palette block to SkyPalette |
| ui-chart-8 | split-function | 3 | medium | M | **backlog** | ChartSky._push: split the 174-line per-frame function |
| ui-chart-9 | untangle | 3 | low | S | **backlog** | ChartSky: typed BakeJob and BakeStage enum |
| ui-chart-10 | dedupe | 2 | low | S | **backlog** | ChartSky family: one bake-pass setup and one set of star tables |
| ui-chart-11 | type-returns | 3 | low | S | **backlog** | MapChart: type the bare returns that have one honest type |
| ui-chart-12 | dead-code | 2 | low | S | **part** | Dead-code sweep: MapChart, StarchartScreen, ChartRadiant, PanelSlide — W1: items 1, 3, 4, 5; item 2 (_gas_palette) rewrites live drawing code |
| ui-chart-13 | dead-code | 3 | low | M | **owner** | TierGalaxy: rule on the procedural fallback that the art strips bypass — TierGalaxy's procedural fallback that the art strips bypass: rule on it |
| ui-chart-14 | bug | 2 | low | S | **owner** | ZoomLadder.world_rest is never cleared between runs — player-visible bug: ZoomLadder.world_rest is never cleared between runs |

### ui-ship

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-ship-1 | dedupe | 4 | low | S | **done** | One hull picture and one engine finder (delete ThrusterFx copies) — W5 |
| ui-ship-2 | split-file | 5 | low | M | **done** | Pull the boss plan phase out of ShipBreakup — W5 |
| ui-ship-3 | split-file | 5 | medium | L | **backlog** | Move the boss film (tick, emit, paint, cargo) out of ShipBreakup |
| ui-ship-4 | split-file | 4 | low | M | **done** | Move the creature set out of ShipBreakup — W5 |
| ui-ship-5 | type-returns | 4 | low | M | **backlog** | A typed HullPic for the hull-picture Dictionary |
| ui-ship-6 | split-function | 3 | low | M | **backlog** | Split _style_tick, _paint_light_new and _setup_new inside ShipBreakup |
| ui-ship-7 | rename | 3 | none | S | **backlog** | Name the bare integers: mote kinds, mark codes, death-style pools |
| ui-ship-8 | dedupe | 2 | low | S | **backlog** | Exact small dedupes and stale comments |
| ui-ship-9 | perf | 2 | none | S | **backlog** | Cache _ring_points (boss paint per-frame waste) |
| ui-ship-10 | dead-code | 3 | low | S | **part** | Remove verified dead code — W1: items 2-7; item 1 (ShipView strip path) needs a pixel check |
| ui-ship-11 | dedupe | 3 | medium | M | **backlog** | Share the hex-shield lattice between ShieldFx and ShipBreakup |
| ui-ship-12 | split-function | 3 | low | M | **backlog** | Split ThrusterFx.for_hull and share the RGBA8 helper |
| ui-ship-13 | split-function | 3 | medium | M | **backlog** | Split CutawayView._layout around a LayoutPass object |
| ui-ship-14 | type-returns | 3 | medium | M | **backlog** | Declare the records in HullScramble and LowHull |

### ui-sysmap

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-sysmap-1 | split-file | 3 | low | M | **done** | Pure curve math out of ShipFlight into FlightCurves.gd — W4b |
| ui-sysmap-2 | split-file | 5 | medium | L | **owner** | Move today's planner out of ShipFlight into OldPlanner.gd — not done: the planner's _high flag leaks between calls on the live ship (see the owner list); moving it to a fresh object per call would change that |
| ui-sysmap-3 | split-function | 4 | low | M | **backlog** | Split SystemView.step (363 lines) into its stages |
| ui-sysmap-4 | split-function | 4 | low | M | **backlog** | Split SystemView.show_system (432 lines) into build stages |
| ui-sysmap-5 | split-file | 4 | medium | L | **backlog** | Move SystemView's inner draw classes to their own files |
| ui-sysmap-6 | dedupe | 3 | low | S | **backlog** | SystemMapScreen.show_system: one opening-framing helper |
| ui-sysmap-7 | dead-code | 3 | low | S | **part** | Delete the proven-dead code in this area — W1: all but PulsarView.hash2 (feeds live rolls) |
| ui-sysmap-8 | move-home | 3 | none | S | **backlog** | Move CoreView.gd out of the game's script folder (dev-sheet painter only) |
| ui-sysmap-9 | dedupe | 3 | low | M | **backlog** | SystemOverlay: one beacon-drawing function and split _draw_ship |
| ui-sysmap-10 | perf | 2 | none | S | **backlog** | SystemView._past_sync rebuilds the shader uniform list every frame |
| ui-sysmap-11 | split-function | 3 | medium | M | **backlog** | Split ShipFlight.free_step (220 lines) into its stages |
| ui-sysmap-12 | type-returns | 3 | low | M | **backlog** | A typed Leg record for the Lambert legs |
| ui-sysmap-13 | untangle | 2 | low | S | **backlog** | CometCatch reaches into ShipFlight privates: add a public plan-to-target call |
| ui-sysmap-14 | bug | 2 | low | S | **owner** | Two first-sentence rules for one encounter (needs owner ruling) — two first-sentence rules for one encounter |

### ui-jump-planets

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-jump-planets-1 | dedupe | 3 | none | S | **backlog** | One rect4(Rect2) -> Vector4 instead of ~25 hand-written packings |
| ui-jump-planets-2 | dedupe | 3 | low | M | **backlog** | One light-buffer builder in JumpStage |
| ui-jump-planets-3 | dedupe | 3 | low | M | **backlog** | Shake noise, bloom gate and mid_y into JumpSequence/JumpPlace |
| ui-jump-planets-4 | move-home | 3 | low | S | **backlog** | hash01 and the hash-shake belong in JumpSequence |
| ui-jump-planets-5 | bug | 4 | low | S | **owner** | SeqUnravel indexes an empty _lag_mats under graphics_low — player-visible bug: SeqUnravel indexes an empty _lag_mats under graphics_low |
| ui-jump-planets-6 | dedupe | 3 | low | M | **backlog** | PhaseTable for the three films that integrate a speed curve at 600/s |
| ui-jump-planets-7 | dead-code | 2 | none | S | **part** | Dead and stale code sweep (Worlds._nudge, LIGHT_K, DEAD_N, DEPART_LEAD, ShatteredView._light, Director comment) — W1: deletions; (e) and (f) refactors not done |
| ui-jump-planets-8 | untangle | 3 | low | M | **backlog** | SeqDatamosh: name info-byte bits, row channels and record rows |
| ui-jump-planets-9 | split-file | 4 | medium | L | **backlog** | Extract the dead-block freeze stage out of SeqDatamosh |
| ui-jump-planets-10 | dedupe | 2 | low | S | **backlog** | Delete SeqDatamosh._box5 by making JumpHull's box/erode/edt public |
| ui-jump-planets-11 | perf | 2 | none | S | **backlog** | SeqMaelstrom builds Pose objects twice per wake point per frame |
| ui-jump-planets-12 | move-home | 3 | low | M | **part** | JumpSeam and two films reach into private state of other classes — W7: ZoomLadder.calm_slide_curve renamed; the accessors not done |
| ui-jump-planets-13 | perf | 3 | low | M | **backlog** | Hoist per-frame colour parsing and array allocs in the planet draw paths |
| ui-jump-planets-14 | dedupe | 2 | low | M | **backlog** | Dedupe PlanetView pad loops and the disc setup shared with ShatteredView |

### ui-misc

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| ui-misc-1 | split-function | 4 | low | M | **backlog** | Hints.probe becomes a dispatch; inline arms move into named helpers |
| ui-misc-2 | split-file | 5 | medium | L | **backlog** | Move the subject probes out of Hints.gd into HintSubjects.gd |
| ui-misc-3 | type-returns | 4 | medium | M | **backlog** | Type the hint snapshot (_base) and split _done |
| ui-misc-4 | dedupe | 3 | low | S | **backlog** | Ash.gd: one corner-layout function and one portrait-on-host helper |
| ui-misc-5 | untangle | 3 | low | S | **part** | Give Ash a public surface on Hints/AshPortrait and share small walks — W7: Hints.pace_ok and visible_transfer public; the rest not done |
| ui-misc-6 | dedupe | 4 | low | S | **backlog** | Pause and Settings drawers share one DrawerShell |
| ui-misc-7 | split-function | 4 | medium | M | **backlog** | Gallery screens: typed filter pick, shared heading, _fill in pieces |
| ui-misc-8 | dead-code | 3 | none | S | **done** | Delete dead code and fix stale comments — W1 |
| ui-misc-9 | perf | 2 | low | S | **backlog** | Hints.poll and Ash._spot per-frame waste |
| ui-misc-10 | perf | 2 | medium | S | **backlog** | CommsPanel PLAY lookup and mark-ring per-frame waste |
| ui-misc-11 | untangle | 3 | low | S | **backlog** | GameShell._apply: one table for the edge styles and looks |
| ui-misc-12 | split-function | 3 | low | M | **backlog** | Split SettingsPanel pages and DisplaySettings.load_and_apply in run order |
| ui-misc-13 | dedupe | 2 | low | S | **backlog** | Widgets.gap and Widgets.chips replace local copies |
| ui-misc-14 | type-returns | 2 | medium | M | **backlog** | Typed comms entry (Ash.Said) with save keys unchanged |

### sim

| Id | Kind | Pay | Risk | Effort | Status | Title / note |
| --- | --- | --- | --- | --- | --- | --- |
| sim-1 | dedupe | 3 | low | S | **backlog** | One ladder-idle wait in Harness |
| sim-2 | dedupe | 3 | low | M | **backlog** | Shared Logger error counter, fit_full and first_system |
| sim-3 | dedupe | 3 | low | M | **backlog** | Input synthesis helpers in Harness |
| sim-4 | dedupe | 2 | low | S | **backlog** | Delete private copies of Harness.arg, frames and seed parsing |
| sim-5 | test | 4 | medium | M | **part** | Gated tests that pass vacuously: assert the precondition — W2: 13 harnesses; some left where the precondition legitimately varies (see W2 report) |
| sim-6 | test | 3 | low | S | **done** | Tools that print FAIL and exit 0, and PASS lines with no check — W2 |
| sim-7 | dedupe | 3 | medium | M | **backlog** | Make harnesses extend or compose Harness for verdict and exit code |
| sim-8 | test | 4 | medium | L | **backlog** | Flaky wall-clock waits in gated tests |
| sim-9 | dead-code | 2 | none | S | **done** | Remove verified dead code inside harness files — W2 |
| sim-10 | dead-code | 3 | none | S | **part** | Unreferenced harnesses: document in tests.md or retire (owner call) — W2: test-map rows added; DerelictShot and the trial-look sheets are for the owner |
| sim-11 | dedupe | 3 | low | M | **backlog** | Shared co-op play driver for CoJoinTest and CoFightTest |
| sim-12 | dedupe | 2 | low | S | **backlog** | Shared steam/weight args for the yard tools, plus a missing deadline |
| sim-13 | bug | 2 | low | S | **part** | Tool-side drift and small bugs (CursorSheet labels, HullDamageFilm hull=, MapShipTest copy, stale constants) — W2: the obvious ones |

## Backlog, best first (payoff high, risk low)

- `ui-chart-2` (split-file, pay 5, medium risk, L): ZoomLadder: lift the calm move into CalmLadder
- `ui-chart-5` (split-file, pay 5, medium risk, L): MapChart: move the star-field generator to ChartFieldGen
- `ui-local-4` (split-file, pay 5, medium risk, L): Extract SectorScreen's zoom-ladder camera into SectorLadder with typed records
- `ui-misc-2` (split-file, pay 5, medium risk, L): Move the subject probes out of Hints.gd into HintSubjects.gd
- `ui-ship-3` (split-file, pay 5, medium risk, L): Move the boss film (tick, emit, paint, cargo) out of ShipBreakup
- `ui-station-5` (split-file, pay 5, medium risk, L): Split LabSavers.gd by owner following LabSaversSolari
- `net-1` (dedupe, pay 4, low risk, S): One _forget_party_state() for the four copied reset blocks
- `ui-chart-4` (type-returns, pay 4, low risk, M): MapChart: typed SkyField replaces SKY_FIELDS and get()/set()
- `ui-chart-6` (move-home, pay 4, low risk, M): StarchartScreen: move Glyph, Crosshair, ChartAhead, MicroGauge and view memory to the chart side
- `ui-chart-7` (move-home, pay 4, low risk, S): ChartSky: move the palette block to SkyPalette
- `ui-local-10` (split-file, pay 4, low risk, M): Extract EncounterView's pack layout into PackLayout
- `ui-local-7` (untangle, pay 4, low risk, M): Give LocalSky a typed face: NearItem, HandOff and accessors instead of get("_x")
- `ui-misc-1` (split-function, pay 4, low risk, M): Hints.probe becomes a dispatch; inline arms move into named helpers
- `ui-misc-6` (dedupe, pay 4, low risk, S): Pause and Settings drawers share one DrawerShell
- `ui-ship-5` (type-returns, pay 4, low risk, M): A typed HullPic for the hull-picture Dictionary
- `ui-station-1` (dedupe, pay 4, low risk, M): LabPage base class for LabAugment/LabRecipes
- `ui-sysmap-3` (split-function, pay 4, low risk, M): Split SystemView.step (363 lines) into its stages
- `ui-sysmap-4` (split-function, pay 4, low risk, M): Split SystemView.show_system (432 lines) into build stages
- `ui-yard-5` (dedupe, pay 4, low risk, M): One scoring loop for seat_pair and YardSlot.seat, one under-scan, one named _ink
- `ui-yard-8` (perf, pay 4, low risk, S): Stop fitting the live Run three extra times per banner click
- `core-5` (split-file, pay 4, medium risk, M): Pull A.S.H.'s voice out of Audio into AshVoicePlayer
- `core-7` (move-home, pay 4, medium risk, M): Move hull-art resolution and rigging tables out of Database into HullArt
- `sim-8` (test, pay 4, medium risk, L): Flaky wall-clock waits in gated tests
- `systems-3` (split-function, pay 4, medium risk, M): Split SaveGame.load_into_run into ordered phase functions and drop the dead Hellbender switch
- `systems-4` (dedupe, pay 4, medium risk, M): SystemLayout: one spelling for job/Hellbender placement, Kepler period, body names, beacons and twin head
- `ui-jump-planets-9` (split-file, pay 4, medium risk, L): Extract the dead-block freeze stage out of SeqDatamosh
- `ui-misc-3` (type-returns, pay 4, medium risk, M): Type the hint snapshot (_base) and split _done
- `ui-misc-7` (split-function, pay 4, medium risk, M): Gallery screens: typed filter pick, shared heading, _fill in pieces
- `ui-station-4` (split-file, pay 4, medium risk, L): Extract the hiring-board deck into StationWorkDeck
- `ui-sysmap-5` (split-file, pay 4, medium risk, L): Move SystemView's inner draw classes to their own files
- `ui-yard-6` (type-returns, pay 4, medium risk, L): Declare the placed-ship record (PlacedShip)
- `systems-5` (dedupe, pay 3, none risk, S): One wreck count and one wreck stream key helper
- `ui-jump-planets-1` (dedupe, pay 3, none risk, S): One rect4(Rect2) -> Vector4 instead of ~25 hand-written packings
- `ui-local-11` (type-returns, pay 3, none risk, S): Type EncounterDrawer.option_state, untaken and quiet_lines
- `ui-ship-7` (rename, pay 3, none risk, S): Name the bare integers: mote kinds, mark codes, death-style pools
- `ui-sysmap-8` (move-home, pay 3, none risk, S): Move CoreView.gd out of the game's script folder (dev-sheet painter only)
- `core-11` (type-returns, pay 3, low risk, M): Typed DockRoute and RefuelOffer for the dock/refuel family
- `core-3` (split-function, pay 3, low risk, S): Split Main._ready along its three seams and read argv once
- `net-3` (split-file, pay 3, low risk, M): Move party-clock and flight statics to PartyClock.gd
- `net-4` (split-file, pay 3, low risk, M): Lift pure foe-turn rules into FoeTurn.gd
- `sim-1` (dedupe, pay 3, low risk, S): One ladder-idle wait in Harness
- `sim-11` (dedupe, pay 3, low risk, M): Shared co-op play driver for CoJoinTest and CoFightTest
- `sim-2` (dedupe, pay 3, low risk, M): Shared Logger error counter, fit_full and first_system
- `sim-3` (dedupe, pay 3, low risk, M): Input synthesis helpers in Harness
- `systems-6` (dedupe, pay 3, low risk, M): Combat: write soak, foe raising, hail/flee gate and victory tail once

## Whole-game simplify review (reuse, simplification, efficiency, altitude)

The earlier review (161 proposals) was broader; this one looked only at reuse, simplification, efficiency and altitude, and about 40 of its findings restate or extend a first-review id. The rest are new, mostly per-frame efficiency items and duplicated helper families. Five changes matter most. (1) One command-line reader and one "sim or headless" check replace the same loop hand-written in about 40 shipping files (415 reads) and 168 scans in sim/. (2) The Lab, lamp, hash and smoothstep copies merge, which is about 250 lines with no behaviour change. (3) Per-frame work that never changes is cached: Router.animating() rescans argv on every call, LabLogin re-deals nine shuffles twice a frame, CometPath bisects 32 evaluations per call, NebulaWeather hashes about 1100 cells for about 450 streaks, and Color("#hex") strings are parsed inside draw loops. (4) The yard open and click hitches: banner rings built 63 times instead of 9, a 161,280-pixel set_pixel loop, and stands rebuilt per click. These timings are estimates. (5) The shipyard hover path: at_tier loads the hull 3 times and builds the art key 6 times, and attributes() rebuilds seven constant dictionaries. I checked about 10 findings by reading the code; most held. I downgraded the JumpFx run-merging item to medium risk and reclassified the duplicate(true) cost as a measurement task. Nothing was run or measured.

233 findings from 24 reviewers; by angle: altitude 42, efficiency 81, reuse 67, simplification 43. Full reports: `sources/simplify/`, synthesis in `sources/simplify/SYNTHESIS.md`.

| Wave | Theme | Removes | Proof | Pixel check | Status |
| --- | --- | --- | --- | --- | --- |
| Wave 1 | Delete dead and copied code in sim, core and systems | The _range_cache member plus about 18 clear lines, about 60 lines of sim helper copies, 5 sprite-loader tails, a 12-line JSON prologue and 9 boss-or-miniboss sites | -- parseall, the full gate (gate_land.sh), -- savetest and the combat sims. Grep sim/ for _on_action("sell") before deleting the dead arm. | no | **backlog** |
| Wave 2 | Hash, ease and lv de-duplication (pure functions) | About 120 lines and 30+ definitions. JumpSequence.ease3/ease5, ZoomLadder._ease_in, LabBoard._dither_ring, BoardCommercial._ease and LocalSubject._h2 stay. | Throwaway probe comparing old and new bit for bit, -- maptest and -- rngtest, and a check that each smoothstep call site has constant, distinct bounds. Lab, chart, sky and yard call sites need Wave 5's new golden groups. | no | **backlog** |
| Wave 3 | Per-frame allocation and caches with exact keys | Argv rescans several times a frame, 18 shuffle draws per lab frame, up to 200 Barker evaluations per frame on comet systems, 2 string formats per moon per frame, a StringName conversion per row in MaterialTable.by_id, and a 36-element Array per system in MapGen | -- rngtest and -- maptest (MapGen must keep one draw and the same modulus), -- solvetest and flighttest for identical doubles, YardPerfTest before and after for the hover path, hints and ash tests. Keep Router.animating's reduced_motion and animate_in_harness checks live. Skipped-redraw items (DimScrim, GameShell, LowHull) move to Wave 5 if pixel proof is wanted. | no | **backlog** |
| Wave 4 | Shared helpers in shipping code (argv, quiet predicate, Widgets, JSON reads) | 168 sim flag scans, about 40 argv loops, 10 quiet-predicate sites, 228 adjacent new_run pairs, about 30 lines of _gap and _chips, 8 JSON read-once copies | -- parseall and the full gate. Keep the two last-wins sites (Router:1186, Main:179) on a separate reader. Keep the LauncherScreen and StarchartScreen _gap mouse_filter flag, and do those two files last because merging them changes click behaviour. | no | **backlog** |
| Wave 5 | Drawing code: shared kits, hoists, caches (split into 5a Lab, 5b yard, 5c sysmap/local, 5d jump/chart, 5e ship) | About 230 lines of copies. Per frame: about 600 draw_rect calls (JumpFx beam), 1100 hashed cells (NebulaWeather), 918-star redraws, about 20k get_pixel per jump-charge frame (ShipView._spooled), and 32,640 pixel reads per frame in the BigCrunch detector. At open: banner ring builds go from about 350k get/set_pixel to about 50k. | Add GoldenFrames groups for lab, yard, chart and sysmap first (none exist today). Capture goldens on main and diff after each sub-step. Hoisted Color constants must be Color8 with identical floats. FieldEdgeTest covers the LocalSky/NavField rig. | yes | **backlog** |

For the owner, from this review:
- core-eff-3 and ui-yard-se-4: measure duplicate(true) cost, then decide on the info-band page cache (medium risk)
- core-altitude-1: move foes= parsing out of Router.start_combat into DevFlags
- ui-station-altitude-3: should TransferScreen._sell_rest count toward n.trades (balance)
- ui-sysmap-altitude-1: should the map clock become GameClock.now() (map films run fast today; player-visible)
- ui-misc-se-3: throttle Ash's speaking-branch avoid check (shifts covered timing by up to 6 frames)
- ui-chart-reuse-7: StarchartScreen STOP to IGNORE gap changes click behaviour
- ui-sysmap-altitude-7: merging the two Lambert solvers moves bits in one planner
- sim-altitude-1: inverting the animate_in_harness default changes timing for about 190 tests
- systems-eff-6: move autosave stringify and write to a worker thread (medium risk, unmeasured)
- Structural tasks: ui-yard-altitude-2/3, ui-sysmap-altitude-3, net-ra-1 with core-altitude-3, ui-misc-alt-1, ui-chart-reuse-1, ui-chart-reuse-8
- ui-sysmap-altitude-5: _nosmooth appears unused; delete unless Jon uses it by hand

## Security review: 13 findings, none critical or high

4 medium, 9 low. None is fixed and none is described here, because this repository is public; James has the detail.

## Test-suite audit

| Id | Finding | Status | Note |
| --- | --- | --- | --- |
| T1 | unit_codecheck defined twice in validate.sh; ran twice in one scratch dir | **done** | W2 |
| T2 | savetest gate check accepted one verdict line of three | **done** | W2 (needs all three) |
| T3 | run_battery.sh always exited 0 | **done** | W2 (exits 1 on a failed row or a failing verdict line) |
| T4 | unit_musiclab never runs in CI (music/tools/node_modules absent, no npm ci) | **owner** | needs a workflow change |
| T5 | LadderTest 2C handover checks and CalmLadderTest drift check are skipped headless | **reported** | noted in their test-map rows (W2); FieldEdgeTest, the backstop, is windowed and nothing runs it |
| T6 | unit_sim has no win-rate or stranded-run threshold | **reported** | may be intended: the sim is a balance tool |
| T7 | SolveTest sweep could pass on zero cases | **done** | W2 |
| T8 | Silent returns with no check in gated tests (LadderTest, FitTest, DockFlyTest, QuestLogTest, ...) | **part** | W2 fixed 13 harnesses; the rest judged legitimate, listed in its report |
| T9 | Tautological _ok(..., true) in LocalEventTest, OptionTest, SystemTest | **done** | W2 |
| T10 | MountCheck and ReactorSheet pass on zero rows | **done** | W2 |
| T11 | SightTest and FitWords print PASS for a check that cannot fail | **done** | W2 (both now say 'measured, nothing judged'; SightTest kept as a measuring tool) |
| T12 | ConvoyTest and SkyTest: named Test, compare nothing | **reported** | not renamed |
| T13 | ShipDriftTest printed FAIL / SKIP and exited 0 | **done** | W2 |
| T14 | StationShot labzoomfilm mode reads LabZoom._veil, removed Nov 5 | **done** | W2 (mode deleted) |
| T15 | DerelictShot photographed a pick that shipped Oct 29 | **owner** | kept; delete only if Jon will not re-photograph it |
| T16 | 12 real headless tests nothing runs (CombatEdgeTest, ZoomGestureTest, SystemGoTest, CloseSaveTest, ShipDriftTest, CombatStudyTest, ConvoySlideTest, HullNumberTest, MapShipTest, TornTest rulesonly, MeterFitTest, LabSaverTest) | **owner** | all pass 3/3; 4-10 s each except MeterFitTest 38 s and LabSaverTest 5.5 min; which join the gate is Jon's call |
| T17 | About 38 working harnesses had no row in docs/tests.md | **done** | W2; 17 look-and-dump tools left without one on purpose |
| T18 | 11 sheets keep rejected looks alive in game code (Rings.Look DUSTY/DARK, ThrusterFx.Look DRIVE/SPILL, HullGrade.reg_look B/C, SystemView.belt_glints, ...) | **owner** | about 2,400 lines of tools; retire the look and its sheet together or neither |
| T19 | Contracts.take() does not refuse a repeat; ContractTest's label claimed it did | **owner** | label reworded in W2; refusing a repeat is a game change |
| T20 | BallHaloTest fails one check on main (work order) | **backlog** | windowed test; not looked at |

## Code graph findings

| Id | Finding | Status | Note |
| --- | --- | --- | --- |
| G1 | Orphan game file systems/HullFit.gd (224 lines) | **reported** | parked on purpose: handbook says written and blocked on art |
| G2 | 36 game functions nothing calls | **done** | W1 (those that survived the per-name grep) |
| G3 | 70 game functions only tests call | **backlog** | each is a test hook that should say so, or code that lost its caller |
| G4 | 41 top-level constants, variables, signals and enums never named again | **part** | W1 took those in its files that passed the grep |
| G5 | Sig.damage_dealt and Sig.overheated: emitted, no listener in game code | **reported** | tests listen |
| G6 | 21 test tools named nowhere | **part** | W2 gave working ones a test-map row |
| G7 | One dependency cycle of 213 game files | **reported** | the W9 ratchet stops it growing; untangling is long-term |
| G8 | 570 call sites on 121 private methods of other classes | **part** | W7 renamed 46 methods; W3 and W5 a few more; BreakupCuts, LocalSky, ShipFlight, SystemLayout families remain |
| G9 | 10 systems-to-ui file pairs, 6 data-to-up pairs, net/BotPilot depends on sim/Policy | **part** | W8: SaveGame/NetSession off SystemMapScreen._parked, SkillCheck colours, Policy moved; SaveGame->Moored/Ash, Ladder->ChartSky, PlaytestLogs->DisplaySettings, Unlocks->DevMode, OptionResolve->bill_rows remain |
| G10 | LabZoom calls LabScene._draw_life through a property chain; the tool cannot see it | **reported** | documented limit of tools/code_graph.py |

## Reviews of the waves themselves

| Review | Found | Status | Note |
| --- | --- | --- | --- |
| Security pass over every diff of the sweep | no critical or high. Game stack: no @rpc, wire field or saved key changed; SaveGame._parked_from still sanitises; moving Policy.gd ships nothing new; the deleted code held no validation. Tooling: no shell injection; tests_for.py --run passes a docs/tests.md row's engine flags to Godot unrestricted (medium, by design); the Claude hooks take their root from the edited file's path (medium-low); code_graph --report used a fixed temp name (low) | **done** | all three fixed (code_graph in #73; the engine-flag allowlist and the accepted-root rule in #85) |
| Guardrails branch: independent review | nothing can damage a repo or lose work; 12 findings: check.sh stamped every pass as 'tests ran', a CRLF checkout could make the pre-commit hook block every commit on Windows, gdcheck checked the wrong tree, command-guard gaps (heredoc paren, ${GODOT:-godot}, find -exec, piped shells, gh pr merge), the Stop hook wrote blobs into .git/objects, frame_check treated a throttle as a cache guard | **done** | all 12 fixed; the hooks self-test grew from 69 to 122 checks |
| W1 code review | 10 leftovers the sweep itself created (newly dead Router functions, no-op tool flags, stale comments, an unsourced 'Jon signed off' comment, an added guard, 3 changelog files) | **done** | all fixed on the branch |
| W2 code review | 8: battery exit hole on FAIL verdicts, SolveTest check that could not fail, ShipDriftTest SKIP, SightTest deleted though only 1 of 4 tables is covered elsewhere, missing test-map rows, typos | **done** | all fixed |
| W9 code review | 10 extractor bugs (parameter types leaking across functions, cast receivers missed, triple-quoted strings scanned as code, keys depending on unrelated files, ...) | **done** | all fixed; self-test covers each |
| W9 simplify review | one call path, layering rules as a table, report() split, named tuples, lazy scopes, shared span helper with code_check | **done** | applied (outputs byte-identical); argparse, a shared baseline module, a gate_py helper and a statement-and-scope rewrite skipped on purpose; the last is written up in docs/why/code_graph.md |

## For Jon (and James) to rule on, beyond the rows marked owner above

- POSSIBLE BUG (player-visible, rare): a refused co-op peer can be told "The host left." instead of the reason. nettest's check "a version 17 peer is explained" got that under battery load (versions 13, 15, 16 beside it passed in the same run) and passed alone 3 of 3. Looks like a race between the refusal message and the disconnect.
- FaunaTest is unreliable headless on the untouched base (found in the helpers wave): of four runs, three crashed (signal 11, exit 134/138) and one failed 2 checks ("winds up", and a call on a freed object in fauna_motion). Same on the changed tree. Not in the gate as far as tests_for shows; worth a look, a freed-object call is a real bug somewhere.
- BreakupCost is a benchmark that prints no verdict; tests_for --run reports it as failed unless its docs/tests.md row says MEASUREMENT or Profiler (PackArmProf's does).
- Possible bug, kept as is (found in the done-once wave): SystemView._Moons.ring_slots caches by world index and rounded radius but not by the moon count, so a world whose moons change at the same radius would reuse the old slots.
- version_guard false positive: a new NetSession line that only READS the wire keys `build` and `dead` (a cached party count) was flagged as a wire change. The wire was unchanged, so the change was dropped rather than raise PROTOCOL. The guard matches key names on changed lines.
- tests_for --run reported PackArmProf as failed (it prints timings and no PASS line). Fixed on #85: a docs/tests.md row that calls itself a Profiler or a MEASUREMENT has no verdict to fail.
- POSSIBLE BUG in ShipFlight's old planner: the pass flag `_high` is not reset on two return paths of `_old_plan` (the star-hohmann loop and the bare-tangent loop). `_fallback` runs the planner on the LIVE ship, not a snapshot, so a `_high = true` left by one call is read by the next call's `_manoeuvre` (`if _high: rw = maxf(rw, L.edge * 0.85)`) before anything assigns it: a different waypoint radius. Rare (a kept choice with high=true that fails, then a hohmann or bare exit, then a second live fallback into the bare path). Fix is one line per path (`_high = false` beside `_tcap = 5.0`), but it changes plans, so it is Jon's call; it also blocks moving the planner out of ShipFlight (ui-sysmap-2).
- FlightTest `retarget` mode fails on the base commit and after: 'the drawn plan's median move, 103.08 px, at most 16'. Nothing runs that mode (not in the gate or the battery).
- Guardrail decisions: the pre-commit hook blocks (one line makes it warn); the command guard blocks a direct Godot start, a push to main, and commit/merge/rebase on main in the main checkout, and only warns on --no-verify and baseline --update; the edit hook uses --import (9 s), which does NOT catch a syntax error in a script nothing loads (parseall, 14 s, does); the Stop reminder is a hook.
- Wrappers that start Godot outside the profile guard: tkg/tools/bot.sh, coplay.sh, cofight.sh (no isolation); cojoin.sh and export.sh isolate with APPDATA/XDG only, which does not isolate on a Mac (Godot reads HOME).
- FLAKY ON CI TOO (seen on #82's run and locally, same line, passes on re-run): TwinSiteTest twin=all failed one check once under machine load ("drawn on the world's orbit as drawn": (430, 251) against (429, 250)) and passed alone twice: it has a wall-clock sensitivity even at --fixed-fps 60.
- Station lag (Jon, Nov 13): the measured script-side cause is the first visit to the Promenade and the Exchange per docking. Not measured (needs a window): the Exchange sky's GPU render on first show, first-use shader compiles per deck, and the Shipyard's 30 Hz CPU composite (about 2.1 ms a tick, both decks visible for a whole slide). Cutting the yard tick would change animation, so it is Jon's call.
- CI on main was red from the push of 67ec663e: `jumpshadertest` was killed at 600 s on the GitHub runner. #76 fixes it (and four limits that were under twice their CI time); land it first.
- Router.salvage_here / _resolve_derelict (wreck stripping) was an unreachable feature body; deleted in W1, in history at 67ec663e.
- AreaView._core / _pulsar are unreachable but docs/why/AreaView.md says they stay for PlaceSheet, which never calls them.
- UITheme's comment says use multiples of 8 for Silkscreen; sizes 10, 11 and 26 are in use.
- W7's new public names (Combat.log_line, ChartSky.shader_rect, MapGen.hash_cell, ...): Jon may prefer others.
- W7 call sites inside windowed film/shot tools parse but no headless test executes them.
- W9: keep the gate unit or take the tool report-only; Hints/Ash not counted as screens; DevFlags/Main exempt; autoload->ui reported, not gated.
- The sim report printed one manufacturer row in a different position once under load (a tie in table order); two clean runs matched. Possibly a pre-existing wobble in report ordering.
- nettest and cofight each failed once when run beside other test runs and passed alone (a map-clock check; a port collision).
- Pixel proof still owed for W5 (GoldenFrames only=breakup,hitfx) and W3 (YardPerfShot): windowed runs, need James's go-ahead.
- Housekeeping from the work order: 25 leftover GitHub branches (14 with merged PRs, 10 with closed PRs #59-#67, #70, #71, plus the orphan 'builds'); nothing deleted yet. The 21 old worktrees are on Jon's PC.

