# Sweep 2, Nov 13 to 14: what to land, what was found, what is yours to rule on

For Jon, from James (written with Claude). This answers the work order "Full sweep:
bugs, speed, cleanup" of Nov 13. James steered it toward maintainability: big files,
copied code, misleading names, tests that could not fail, and checks that catch the
next mistake when it is made. Nothing here is meant to change how the game looks,
sounds or plays. Where a change could, it says so and names the check that is owed.

Every finding, with its status, is in [`LEDGER.md`](LEDGER.md) beside this file.

## Land this: one branch

Everything is on one branch, `sweep-2/all`, as one PR into `main`. One run of
`gate_land.sh` lands all of it:

    bash tools/dev/gate_land.sh <a worktree of sweep-2/all> sweep-2/all sweep2

`gate_land.sh` fast-forwards `main`, so every wave's commits stay in history, in
order, and a later `git bisect` can still walk them one wave at a time.

It was first opened as seventeen PRs, one a wave, as the work order asked. James
folded them into one so that landing is one gate run and not seventeen. The wave PRs
are closed, not deleted: each still shows its own wave's change alone, with its
proof, and its number is in the table for when you want to read one.

| Wave PR (closed) | What | Proof | Owed |
|---|---|---|---|
| #76 | CI was red on `main` since Nov 11 for a reason that is not a bug: `jumpshadertest` could not finish on the runner's software renderer. It now runs alone at 15 frames a second there. Four gate limits that had drifted under twice their CI time are raised. | all four CI parts green | nothing |
| #82 | Your report of lag when changing floors in the station. The first visit to the Promenade or the Exchange after docking built the room on the frame you arrived. The rooms are now built one step a frame once the dock is quiet. | first ride 30 and 49 ms down to 3.2 and 3.4 ms (headless); a test proves both rooms end in the identical state | a windowed look; the graphics-card side was not measured (below) |
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
| (no wave PR) | **Party input.** The host ignores or trims bad, oversize and late input from another ship: a flight with no duration, a build carrying more than a ship has, more claims than a system can hold, a connection that never says hello. `PROTOCOL` stays 20. | new checks in `nettest`, each failing on the old code | your ruling on two visible things, below |
| (no wave PR) | **Relay limits.** The relay answers a path that is not a party code without waking a party, drops a frame over the game's buffer, closes a socket far faster than a ship, and gives back the seat of a guest that never speaks. | 20 node tests, now a gate unit (`relaytest`); codes checked against 300 the game made | nothing: **live since Nov 14** (James's deploy, from this branch), and checked on the live address |
| (no wave PR) | **Damaged files.** A save with a wrong-typed field is refused whole before the run is touched; SAVE MY LOGS scrubs the settings, save and history files too; CI's Godot download and its actions are pinned. `VERSION` stays 43. | 44 cases in `savetest`; `menutest` | nothing |

The rows are in the order the commits sit on the branch, except the first two, which
were cut from `main` and merged in. The last three were added after the fold and have
no wave PR: each is one merge on the branch (`fix/party-bad-input`, `fix/relay-limits`,
`fix/damaged-files`).

Two rows change how you and your Claude work, not the game: #73 (the code graph as a
gate check) and #85 (the guardrails). **Read #85's page before landing.** Each of its
blocks is one line to turn into a warning; the lines are under "Yours to rule on".

CI runs only on a PR into `main`, so this branch is the first time the stack goes
through CI: while it was seventeen PRs, the stacked ones showed no checks. The
battery was run by hand at each level of the stack (the numbers are on each wave's
page). On the tip of the stack (#88) it passed 58 of 59; the one failure is the
`nettest` race below. It was run again on this branch with the last three merged in;
that result, and CI's, are on the PR's page.

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
- **`stationdecktest`, one line once on CI.** "capital, every ride: mid-ride the
  moving decks take no click and the rail does" failed on the first CI run of this
  branch's tip and passed on a re-run. The test clicks six frames into a ride and runs
  on the wall clock, without `--fixed-fps`, so on a slow runner frame the ride is over
  before the click. The background room loader of the floor-change fix stands still
  while a ride moves, so it adds no work there.
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
- **Party input, two things a player could see.** A callsign typed with square
  brackets now shows without them on every machine, and an empty one shows as PILOT.
  One system holds at most 1,024 claims and the party 16,384 (ten eight-ship fights
  stripped bare at one system; about twice a galaxy stripped bare). Past either, a
  take is refused. Raise them if you would rather.
- **The relay limits are live.** Deployed on Nov 14 from this branch, before it
  landed: until it does, `relay/` on `main` is older than the relay that is running.
  No client build was needed. Checked three ways, first on a local `wrangler dev` and
  then on the live address: 30 checks by a script that talks to the relay as ships do
  (each limit, each refusal, each close code); two copies of the game as it is on
  `main` flown through a whole `cojoin` dive; and two copies of this branch's game,
  with a late join. All passed. `wrangler rollback`, run in `relay/`, puts the August
  version back. Left for a ruling: a guest that says hello and is then refused cannot
  be removed on the relay without a new relay frame; a per-address rate rule belongs
  in the Cloudflare account; longer codes would change what players type.
- **A ship's own machine reports its hits,** and the host checks only that they are in
  range. Left as it is: a friends' game.
- **`nettest`, one line once.** "a spot that holds still is not said again within a
  beat" failed once in 11 runs with the party-input change, on a machine under heavy
  load, and never in 12 runs without it. The test reads a stale stamp when an
  unreliable message does not arrive. Not explained further.

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
