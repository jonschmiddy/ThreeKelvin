# Handoff, Nov 1 2026: twin stars and flight length, Mac to PC

Written at the end of a long Mac session (Oct 30 to Nov 1) so a Claude session on
Jon's Windows PC can carry on without it. Read `tools/dev/README.md` first (how we
work), then this.

## Where it stands

- **Branch:** `feat/twin-fix`, pushed to origin. `feat/twin-stars` points at the
  same commit. Both hold ruling 20's whole build: 22 commits on top of main
  (a6ed7f5e), 56 files, about 14,800 lines. **Not on main yet.**
- **Ruled since the build:** Jon picked **Flight length: C** on Nov 1 (ruling 21).
  **It is not built yet. It is the next job** (below).
- **main** is a6ed7f5e (ruling 17, the Custodian keeps 200 under enemy hull x2).
- Nothing is running on the Mac. No gate was started for this branch.

## The next jobs, in order

### 1. Build flight length C (ruling 21) on feat/twin-fix

Jon picked C from the Autopilot Flight Time page
(https://claude.ai/artifact/MA9ZG1deDv4DYwG5889nWu), which played eight flights at
game speed at three settings. The study behind it is in `flight-length/` here:
`summary.md` has every number.

| | TIME_W | T_CAP | one sun, place to place (median / 9 in 10 / worst) | first flight after a jump |
|---|---|---|---|---|
| A, as built today on the branch | 0.5 | 30 | 23.5 / 29.6 / 30.6 s | about 29 s |
| B | 1 | 23 | 18.9 / 23.0 / 23.7 s | about 23 s |
| **C, picked** | **16** | **16** | **10.8 / 14.9 / 20.0 s** | **about 18 s** |
| today's autopilot (main) | | | 6.9 / 9.7 / 12.1 s | about 7.5 s |

What C needs, all in `tkg/scripts/systems/FlightSolve.gd`:

- **The fallback**, from `flight-length/study.patch` (it applies cleanly on
  e1d38bfa: `git apply --check` passed). With C's dials alone the solver misses
  10 of SolveTest's 12,648 flights that A finds (9 in twins, mostly from a settled
  star orbit to a station). The patch adds:
  - `_fresh`, `_search_back`, `_tier_of_cap`, `_tw`;
  - both guess lists (C's scaled conic guesses plus the as-built ones under its cap);
  - "the sooner of two": where C's own search finds nothing, the as-built search
    (TIME_W 0.5, T_CAP 30) and the wider search at C's TIME_W both run, and the
    earlier arrival is kept;
  - a two-leg flight's legs always use the as-built search.

  The fallback is about 100 lines. The patch has about 70 more lines of study-only
  tuning hooks (`fs.tw`, `fs.cap`, `fs.capw`, `fs.back`, `fs.both` from the
  command line, used by `set.C=16:16:40::30:both` in `run_v3.sh`). Land the
  fallback properly and drop the hooks; set C as the constants.
- **C's constants** (replays.json's `settings.C`): TIME_W 16, T_CAP 16,
  T_CAP_WIDE 40, T_CAP_BACK 30, WIDE_T 20, FAR_T 9.6, CHAIN_T 15, LEAD_MAX 4.4.
  Conic guesses 3.2, 4.8, 6, 6.93, 9, 9.6, 12.8, 13, 15.47 s (the as-built 6, 9,
  13, 18, 24, 29 times 16/30, plus the as-built ones under 16). Wide guesses 18,
  24, 29, 34, 39.
- **One failing check to fix:** SolveTest's cusp check fails in 1 of 2,610
  real-twin flights at C: a burn slows under 5 px/s, drawn as a cusp. The study
  named it seed 4242 node 281, alongside a station to world 0.
- **One test-only start:** FlightTest's harness free start at seed 4242 system 291
  (free, to world 1) gets a flight 0.72 px into a keep-out. It counts as found but
  not clean, so the fallback never runs. Probably run the fallback for an unclean
  find too.
- **Words in code:** the TIME_W comment ("Jon's dial", 0.5 as built) and
  FlightSolve.gd:224's note on v2's 18 to 23 s; SolveTest and FlightTest
  expectations (FLY_MAX and the like, if any assume 30 s); the FlightTest and
  SolveTest rows in `tkg/CLAUDE.md`.
- **What full runs should show after** (the study's C, FlightTest full):
  - every game start found, as A (694/696, 917/917, 1478/1478), put there 0;
  - one sun, every game start 13.4 / 18.3 / 27.3 s; heavy giant, place to place
    11.3 / 15.5 / 28.2;
  - twins, every game start 14.0 / 21.1 / 57.8;
  - two-leg flights 30 of 1,790 twin plans, median 47 s;
  - engine work median 157 px/s (A 91);
  - planning ms median 15 (one sun) and 45 (twins), worst 535 and 734;
  - SolveTest found 3870/3888, 4647/4656, 3024/3024, 1080/1080.
- **Things the study found that stay true at C:** C lands later than A from about
  1 game start in 55, by up to 6 s. Twin flights change by up to 13 s with the
  moment you click. The study's harness had one headless quirk (the arrival
  point computed before the map's frame had a size); it is fixed in
  `FlightLen.gd`'s `_game_edge`, and the game itself was never affected.

### 2. The twin looks sheet (needs stills: ask Jon before any windowed run)

Open choices from the third review that the code settled one way but Jon has
not ruled on. One sheet, a letter per item, real stills of a twin:

1. **A ship on the ring of a world that circles one sun sits on the world's
   disc** (100% of the ride at the opening zoom, 31% at zoom 1, TwinDrawTest).
   Options A to D; A, a 1 px outline, is recommended.
2. **The giant's MASS row** takes FAUNA's place when FAUNA reads NONE (as built),
   or gets a row of its own (a twin's page then has 9 rows).
3. **Orbits are capped 2 px short of the next disc,** but the tilt still brings
   a world onto its sun, above and below.
4. **A TWO SUNS entry in the star chart's KEY.**
5. **The SATELLITES list grouped by star.**
6. **No city worlds in twins:** a twin's worlds round one sun always land in
   zone 0 (the hot pool), so a twin never has a city or megacity world, even at
   a CITY or CAPITAL system.
7. **The capture rule changed for one sun too:** letting go by hand now takes the
   ring the line reaches, or the nearest, where it took the first world by index
   (17 of 20 multi-ring states with one sun go differently).
8. **Star B's mass:** it reads ORANGE DWARF, K5, 4,400 K (fits the drawn colour),
   MASS 0.72 to 0.92 SOL (from the pull ratio, star A at 1.0) where a K5 star is
   about 0.70. The pair reads 1.72 to 1.92 SOL while the map pulls as one sun.

Also look at, in the same stills: PAINTED's rims beside star B, the moon tint
round star B, LOCAL in PAINTED (its feed was never checked headless), the event
card at its new width, and hover during a GO.

Earlier wave-3 items already fixed (no need to ask): two-leg flights (1,478 of
1,478 found), SectorPainted's rims, the 231-of-226 px event card.

### 3. The battery on the final tree

`twin-build/run_all.sh` is the list of 35 harness runs used on the Mac (Mac paths,
the Mac's lock `tk-scratch/godot1.sh`). Run the same set on the PC after C is
built. The last full battery (Oct 31, on 8f257a76) passed everything except two
things that are now fixed: FlightTest's twin found rate, and scrollcheck's exit
crash, fixed by `ShipFlight.drain()` at quit. TwinSiteTest, TwinDrawTest,
FlightTest (short) and SolveTest (short) are merge-gate units in validate.sh.

### 4. CHANGELOG and DEVELOPMENT_PLAN

- `twin-build/changelog_draft.md` has the lines. With C, the autopilot line reads
  "A flight from place to place takes about 11 seconds, where it took about 7."
- DEVELOPMENT_PLAN on this branch has ruling 20's row and now ruling 21's (this
  commit). Phase 13 step 5 says what was built.
- Run `python tools/prose_grade.py --all` and `python tools/prose_tells.py` on
  the new player text.
- **Merge notes for the release:** SaveGame VERSION 38 (`twin`); a save from
  before loads with one sun everywhere. NetSession PROTOCOL 13: partners on
  0.4.2-alpha.1 cannot join a host on the new build; say so in the release notes.
  Never raise RunHistory.VERSION.

### 5. Land it

One `tools/dev/gate_land.sh <worktree> feat/twin-fix "<label>"`, alone on an idle
machine. The PC is faster; the Mac's gate took about 12 minutes plus the twin units.

## What ruling 20 built (for orientation)

Jon, Oct 30, "Prototype: twin:A giant:A": two-star systems and giants at 1/10 to
1/4 of their star ("purely because it's more fun"). Autopilot only; WASD stays
free of gravity; flying inside a system costs no fuel.

- **Layout** (`SystemLayout.gd`, `MapGen.gd`): about one ordinary system in four
  is a twin. Star A at the origin, star B is place -4 (`SystemLayout.STAR_B`),
  bodies round both have host -9. Each star has a close orbit and keep-out.
- **Flight** (`FlightSolve.gd`, 3,250 lines, new; `MapGravity.gd`, new;
  `ShipFlight.gd`): every autopilot flight is solved through both stars and the
  moving giant on map time, at THRUST 40, planned on a worker and flown exactly as
  drawn. Where one leg reaches nothing, a twin flies two (`_chain`). Hand flying
  works in a twin. A ship let go settles clear of rings, inside the map, never in
  a sun.
- **Drawing** (`SystemView.gd`, `SystemOverlay.gd`, `LocalSky.gd`, `SunView.gd`,
  `StarchartScreen.gd`, `sky_nebula.gdshader`, `sector_b_paint`): two suns on the
  map, in LOCAL and on the chart; each world lit by its own sun; PAINTED's far
  cloud edges face both suns.
- **Places** (`SystemPanel.gd`): star B is a place everywhere star A is (FLY
  HERE, tips, the panel's TWO SUNS page); the fact row says AROUND; star facts
  come from `SystemView.star_facts_of`; a giant's page shows MASS.
- **Fixes on the way:** leaving the map mid-flight keeps the flight; a style or
  GRAPHICS LOW change during a GO keeps its errand; quitting waits for a plan
  still on a worker (it crashed); during a GO the map takes hover, zoom, drag and
  right-click, and refuses clicks, FLY HERE and WASD.
- **Tests, new:** SolveTest, FlightTest (rewritten), TwinSiteTest, TwinDrawTest.

## Pages for this work

- Autopilot Flight Time (ruled C): https://claude.ai/artifact/MA9ZG1deDv4DYwG5889nWu
- Twin Stars Prototype (ruling 20): https://claude.ai/artifact/Q34NXdQ7gDoY8FpzR8mHHV
- Giant Assist On Map Time (ruling 18): https://claude.ai/artifact/5vHCvoFtXTCS9q72kQmyoY
- Flight And Orbits (Orbits v2, "flight:N clock:map assist:pays"): https://claude.ai/artifact/SdKxV681s95qucnVjT3ff6
- Post-Alpha Roadmap: https://claude.ai/artifact/XmtjvY3zXqGfW65tLhEDEu

`flight-length/page/` rebuilds the flight-length page:
`python3 assemble.py replays.json copy.json out.html`. replays.json (1.8 MB) is
not in git; `FlightLen.gd` makes it again (copy it into `tkg/scripts/sim/` of a
detached copy with study.patch applied; `run_v3.sh` and `run_edgefix.sh` show
the arguments, then `finalize_replays.py`).

## Offered earlier, not started

- the word "fuel" on the Flight And Orbits page;
- a 0.4.3 build for the friends;
- a text-only gate shortcut;
- the roadmap page;
- committing `MapShipShot.gd` (in the `tk-wt/map-own-ship` worktree on the Mac,
  uncommitted; real-screen stills through Router.show_system, needs twin support);
- the hover readout overlapping star labels;
- the Phase 15 page;
- unique art.

## What stays on the Mac

- `tk-scratch/` (2.6 GB, not in git): every log and probe of this build. What the
  next jobs need is copied here. The rest is under
  `/Users/jon/Documents/GitHub/tk-scratch/twin-build/` and
  `/Users/jon/Documents/GitHub/tk-scratch/twin-build/flightlen/`.
- `tk-scratch/godot1.sh`, the Mac's one-Godot lock. On the PC, use the hidden
  desktop (TK_HIDDESK) for windowed runs, as before.
- Claude's memory and this session's transcript: Jon has a zip of both from the
  Mac (`claude-handoff-2026-11-01.zip`). The memory folder goes into the PC's
  project memory folder; several notes were written on the Mac and are not on the
  PC yet.
