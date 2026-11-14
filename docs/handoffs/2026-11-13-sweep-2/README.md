# Sweep 2, Nov 13 to 14: what to land, what was found, what is yours to rule on

For Jon, from James (written with Claude). This answers the work order "Full sweep:
bugs, speed, cleanup" of Nov 13. James steered it toward maintainability: big files,
copied code, misleading names, tests that could not fail, and checks that catch the
next mistake when it is made. Nothing here is meant to change how the game looks,
sounds or plays. Where a change could, it says so and names the check that is owed.

Every finding, with its status, is in [`LEDGER.md`](LEDGER.md) beside this file.

## Land these, in this order

Two PRs stand alone on `main`. Land them first: the first turns CI green.

| PR | What | Proof | Owed |
|---|---|---|---|
| #76 | CI was red on `main` since Nov 11 for a reason that is not a bug: `jumpshadertest` could not finish on the runner's software renderer. It now runs alone at 15 frames a second there. Four gate limits that had drifted under twice their CI time are raised. | all four CI parts green | nothing |
| #82 | Your report of lag when changing floors in the station. The first visit to the Promenade or the Exchange after docking built the room on the frame you arrived. The rooms are now built one step a frame once the dock is quiet. | first ride 30 and 49 ms down to 3.2 and 3.4 ms (headless); a test proves both rooms end in the identical state | a windowed look; the graphics-card side was not measured (below) |

Then the stack. Each PR is cut from the one before it, so each PR's page shows only
its own change. Land them top to bottom with `gate_land.sh`.

| PR | What | Proof | Owed |
|---|---|---|---|
| #74 | Code nothing calls is deleted: 2,043 lines out of 111 files. | battery 58 of 58; seeded sim identical | nothing |
| #75 | The test suite tells the truth: checks that could not fail now can, a gate unit that was defined twice is defined once, the battery exits 1 when a row fails. | battery 58 of 58 | nothing |
| #77 | 46 methods that other files call lose the underscore that said they were private. | every changed line explained by the rename list | nothing |
| #78 | Run state and rules helpers leave screen code; the pilot model leaves the test folder. | moved bodies identical | nothing |
| #79 | Shipyard code moves to the files its names promise. | moved bodies identical | windowed: YardPerfShot, stationshot |
| #80 | `ShipBreakup` goes under the 3,000-line cap (3,639 to 2,886). | moved bodies identical | windowed: GoldenFrames `only=breakup,hitfx` |
| #81 | `LocalSubject` (3,167 lines) becomes a planner, the masks and a node. | 39,798 staging plans identical | nothing |
| #83 | `FlightSolve` sheds its two-leg planner and its pure math (3,969 to 3,614). | flight and solver totals identical | nothing |
| #84 | `ShipFlight`'s curve math moves out (4,386 to 4,150). | same | nothing |
| #73 | `tools/code_graph.py`: a map of which script calls which, and a gate check that stops new tangles. | self-test; baseline of 134 known reach-ins | your ruling: gate it or report only |
| #85 | Guardrails: commits checked in 5 seconds, three more ratchets, and hooks that steer a Claude session. **Read this one before landing; it changes how commits and sessions behave.** | 122-check self-test; two independent reviews | untested on Windows and in a live session |
| #86 | Colours used by drawing code are read from text once, not every frame (126 constants in 31 files). | each constant put back as its literal: no code line differs | windowed sheets listed in the PR |
| #87 | Small helpers that were copied between files are one function each (23 copies gone). | each pair compared over at least 100,000 inputs, bit for bit | nothing |
| #88 | Work that gave the same answer every call is done once (the launch arguments, the material table, the lab's screensaver deal, the board lamp). | 33,377 cached answers compared with fresh ones, 0 differ | nothing |

CI runs only on a PR into `main`, so the stacked PRs show no checks until the one
below them lands. The battery was run on the stack by hand at each level; the numbers
are in each PR. On the tip of the whole stack (#88) it passes 58 of 59; the one
failure is the `nettest` race below.

## What you can now run

- `bash tools/dev/check.sh` before saying a change is done; `--tests` also runs the
  headless tests the change needs.
- `python3 tools/dev/tests_for.py` says which rows of `docs/tests.md` a change needs.
- `python3 tools/code_graph.py --report` lists orphans, private methods called across
  files, and rules code that reaches into screens.
- `python3 tools/frame_check.py --report` lists work done every frame that belongs
  outside the frame, worst first.
- `GATE_STATIC=1 bash .github/scripts/validate.sh` runs the gate's 20 checks that need
  no Godot, in about 5 seconds. The pre-commit hook runs the same set.

## Possible bugs, found and not fixed

Each of these would change what the game does, so it is your call.

- **`ShipFlight._high` is not reset on two return paths of `_old_plan`.** The fallback
  runs the planner on the live ship, so a flag left set by one call is read by the
  next and gives a different waypoint radius. Rare. The fix is one line per path, and
  it changes plans. It also blocks moving the old planner out of `ShipFlight`.
- **`SystemView`'s ring-slot cache** is keyed by world and radius but not by the moon
  count: a world whose moons change at the same radius would reuse the old slots.
- **`Contracts.take()` accepts a repeat.** ContractTest's label claimed it refused one.
- **`LocalSky._wx_place`** can produce a band of zero height.
- **A refused co-op peer can be told "The host left." instead of why.** `nettest`'s
  check "a version 17 peer is explained" got that once under load and passed alone
  three times; versions 13, 15 and 16 beside it passed in the same run. It looks like
  a race between the refusal message and the disconnect. A player on an old build
  would see the wrong reason.
- **FaunaTest is unreliable headless on an untouched tree:** of four runs, three crashed
  and one failed two checks, one of them a call on a freed object in `fauna_motion`.
- **`FlightTest retarget` fails on `main`** ("the drawn plan's median move, 103.08 px,
  at most 16"). Nothing runs that mode.
- **TwinSiteTest `twin=all` is flaky,** on CI and locally: one check that rounds to a
  pixel fails about one run in several and passes on a re-run. The world's position in
  the failing line differs between failures, so something tied to the wall clock feeds
  it even at `--fixed-fps 60`.
- **BallHaloTest** (the work order's known failure) was not looked at: it is windowed.

## Yours to rule on

- **The station lag is half measured.** The script side is fixed in #82. Not measured,
  because it needs a window: the Exchange sky's first render on the graphics card,
  first-use shader compiles per deck, and the Shipyard's 30 Hz composite (about 2.1 ms
  a tick with both decks visible for a whole slide). Cutting the yard's tick would
  change its animation.
- **Guardrails (#85):** the pre-commit hook and the command guard block; one line each
  makes them warn. `gh pr merge` is blocked for the assistant. The edit hook uses
  `--import`, which did not catch a planted syntax error in a script nothing loads;
  `parseall` did, at 14 seconds against 9.
- **Five wrappers start Godot outside the profile guard:** `tkg/tools/bot.sh`,
  `coplay.sh`, `cofight.sh` (no isolation), and `cojoin.sh`, `export.sh` (isolated on
  Windows and Linux only; on a Mac Godot reads `HOME`).
- **Twelve real tests nothing runs:** CombatEdgeTest, ZoomGestureTest, SystemGoTest,
  CloseSaveTest, ShipDriftTest, CombatStudyTest, ConvoySlideTest, HullNumberTest,
  MapShipTest, TornTest `rulesonly`, MeterFitTest, LabSaverTest. All pass. Each takes 4
  to 10 seconds except MeterFitTest (38 s) and LabSaverTest (5.5 min).
- **`unit_musiclab` never runs in CI** (its node modules are absent there).
- **Eleven sheets keep rejected looks alive in game code,** about 2,400 lines. Retire a
  look and its sheet together, or neither.
- **The wreck-stripping feature** (`Router.salvage_here`) could not be reached and was
  deleted in #74. It is in history at 67ec663e if it was parked, not dead.
- **New public names in #77** (`Combat.log_line`, `ChartSky.shader_rect`,
  `MapGen.hash_cell` and 43 more): rename any you would have called something else.
- **`version_guard` flags a line that only reads a wire key.** A cached party count in
  `NetSession` was dropped for it; the wire was unchanged.
- **Two doc contradictions:** `docs/why/AreaView.md` says `_core` and `_pulsar` stay
  for PlaceSheet, which never calls them; `UITheme` says sizes are multiples of 8 and
  uses 10, 11 and 26.
- **Security:** a review of the netcode, the relay, saves and the build scripts found 13
  items, none critical or high, four medium. They are not fixed and not written here,
  because this repository is public. James has the detail.

## Not done

- `ShipFlight` and `FlightSolve` are still over the 3,000-line cap.
- 8 colours in `SectorScreen._draw` and `StationScreen._draw` are still parsed every
  frame: both files are at their recorded size and may not grow.
- 116 smaller proposals from the first review, ranked, are in the ledger's backlog.
- About 30 new private reach-ins came from splitting `ShipBreakup` and `LocalSubject`;
  the code graph's baseline records them. An explicit interface between `ShipBreakup`
  and its two new files would retire most.
- The work order's housekeeping: 25 old GitHub branches of James's (none deleted), and
  the 21 old worktrees on your PC.
- No windowed run was made in the whole sweep, so no pixel was compared. The proofs
  above are of code and values, not pictures.
