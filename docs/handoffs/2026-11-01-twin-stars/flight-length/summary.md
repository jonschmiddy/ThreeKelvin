# How long an autopilot flight takes: the study (Nov 1, corrected after review)

Ruling 20's solved flights at three settings, with today's planner (the
pre-branch autopilot, `_old_plan`, flown as main's map flew it) beside them.
Measured headless on this Mac, one Godot at a time, on a detached copy of
feat/twin-fix at ee5ef1d3 (removed after). The first version of this page, the
one the review read, is kept in before_review/.

**Times** are seconds from the click to settled in orbit (or alongside). The
map's clock moves by each frame's time (`SystemMapScreen._process`:
`view.t += delta`, the same sum GameClock keeps), and nothing on the map scales
it, so 1 s of map time is 1 s on the wall at 1x.

## What the review changed

| the review found | what was done | what it changed |
|---|---|---|
| Each twin replay was one sample from a wide spread | Each flight is flown at ten selection moments 0.1 s apart, at every setting. The run nearest each setting's median is kept, and the table gives the range | Twin flights move by up to 13 s with the moment (world round A to world round B: A 16.9 to 28.9 s, B 7.1 to 20.4 s). One-sun flights move by under 1 s (the edge's old spread came from its wrong start, below) |
| B flew longer than A in about a fifth of game starts | B and C keep the as-built guess times under their cap beside the scaled ones | FlightTest game starts where B lands over 0.3 s after A: one sun 132 to 37 of 696, giant 174 to 63 of 917, twins 189 to 131 of 1,478 (by over 5 s: 72 to 45) |
| The fallback ran the setting's own wider search (to 40 s) before the as-built search (to 30 s) | Where the setting's own search finds nothing, the as-built search and the wider one both look, and the flight that arrives first is kept (below) | Game starts where A lands within 31 s and the setting takes over 31 s: B 31 to 0, C 4 to 0 |
| Today's planner was planned fresh at the click | Its preview is made at the selection, and the click flies from the preview's own choice, which keeps its arrival time, as main's `fly` did | One sun, place to place: 7.2 / 9.9 / 12.4 s before, 6.9 / 9.7 / 12.1 s now |
| Today's planner was shown in twins | Dropped. The game never flies it in a twin (`ShipFlight._fallback`), and main had no twins | The four twin replays have no today's run |
| "The 29 s guess nearly always wins" | Reworded below | |
| The grid rows marked B and C were the dials alone | Relabelled, and the corrected B and C added | |
| Replay positions were unrounded | The ship's samples are whole px as `_draw_ship` rounds them; world centres are on the 2 px block grid | The exact point differs from the drawn one by up to 0.5 px with one sun, 1.8 px in twins |
| Two Godots ran at once | **Did not hold** (below). The planning ms were run again alone anyway | Worst planning ms, SolveTest real twins: A 510, B 768, C 751 (the study had 522, 970, 760) |

**Two Godots at once did not happen.** The clocks went back an hour at 2:00 on
Nov 1 (CDT to CST), so 1:00 to 2:00 came twice. The review read the logs' local
times, which put runs of the first 1 AM hour beside runs of the second. In UTC
no two confirm runs overlap: from ft_A_short at 06:06Z to solve_A2_full at
08:25Z each began after the one before it ended (12 to 15 s after, within one
script). The study's own transcript agrees: its confirm runs started at 06:07Z
and were stopped at 07:07Z, and the next script started at 07:18Z. The lock
worked. In this pass a watcher counted
Godots every 15 s through every run (513 samples) and never saw more than one.
The review's 768 ms for B, against the study's 970 ms, is the worst single plan
of about 3,000; this pass got 768 ms too. A worst plan moves from run to run:
read the medians.

## What sets a flight's length

- The solver tries a short list of flight times (its conic guesses: 6, 9, 13,
  18, 24 and 29 s as built), re-solves the six rough conics that look cheapest
  and keeps the cheapest flight, where cost is engine work plus TIME_W times
  the seconds.
- T_CAP sets the longest flights, and they are under half. At A, 46% of solved
  one-sun flights end between 27 and 30 s (38% with a giant, 38% in twins), and
  23% end under 15 s (28% in twins). The median is 24 s.
- So T_CAP cuts the long flights, and TIME_W only matters once it is large
  enough to beat the work a longer flight saves: about 1 for B, about 16 for C.
- B and C scale the guess times with the cap (x 23/30, x 16/30) and now keep
  the as-built ones under their cap too. With the scaled ones alone, B flew
  longer than A in about a fifth of game starts.

## The three settings

| | TIME_W | T_CAP | guess times (s) | where its own search finds nothing |
|---|---|---|---|---|
| A, as built | 0.5 | 30 | 6, 9, 13, 18, 24, 29 | the wider search, to 40 s |
| B, your v2 pick | 1 | 23 | 4.6, 6, 6.9, 9, 10, 13, 13.8, 18, 18.4, 22.2 | the sooner of two: the as-built search (to 30 s at TIME_W 0.5) and the wider one at TIME_W 1. If both find nothing, the as-built wider one |
| C, quick | 16 | 16 | 3.2, 4.8, 6, 6.9, 9, 9.6, 12.8, 13, 15.5 | the same, the wider one at TIME_W 16 |

**The fallback is a code change, not a dial.** It is about 100 lines of the
study copy's FlightSolve.gd (`_fresh`, `_search_back`, `_tier_of_cap`, `_tw`),
saved as study.patch, and it is off when T_CAP_BACK is 0. A two-leg flight's
legs always use the as-built search, so those flights keep A's length: 30 to
37 of 1,790 twin plans, median 46 to 47 s.

**Why the sooner of two.** The review asked for the as-built search before the
wider one. That pass (kept in v2a/) held B and C to A's times, but C's own 16 s
search finds nothing from the edge or a settled star orbit in one game start
in five to eight (102 of 694 one sun, 106 of 917 giant, 303 of 1,478 twins). The
as-built search flies those in about 29 s, where C's wider search had found
quicker ones. Over every game start, C's p90 went from 18.2 to 29.0 s with one
sun, 16.6 to 27.5 s with a giant and 21.1 to 29.1 s in twins. Keeping the
sooner of the two gives C its quick flights back (18.3, 18.0 and 21.1 s) and
never arrives after the as-built search's flight. The cost is planning time
where both run: at C, SolveTest's real twins plan at a p90 of 147 ms against
114.

## Do B and C still need the fallback?

Yes. SolveTest's 12,648 plans, solved in one process at each setting and
compared case by case. "Dials alone" is the setting with both guess lists and
no fallback:

| setting | finds that A misses | misses that A finds | of those, by sweep |
|---|---|---|---|
| B | 0 | 0 | - |
| B, dials alone | 0 | 2 | giant 1, rtwin 1 |
| C | 1 | 0 | - |
| C, dials alone | 1 | 10 | giant 1, rtwin 9 |

Keeping the as-built guesses did not stop the dials alone from losing flights:
B alone still misses 2 that A finds and C alone 10 (9 in twins, mostly settled
star orbits to a station). With the fallback, both miss none, and C finds one
A misses.

## Longer than A, case by case

FlightTest's game starts, each setting against A from the same start and the
same click (both landed):

| | sweep | both landed | longer than A by over 0.3 s | by over 5 s | worst | shorter | A under 31 s, this over 31 s | extra engine work, median px/s |
|---|---|---|---|---|---|---|---|---|
| B | one | 696 | 37 (5%) | 3 | +11.6 s | 560 (80%) | 0 | +12 |
| B | giant | 917 | 63 (7%) | 7 | +10.1 s | 702 (77%) | 0 | +7 |
| B | twin | 1478 | 131 (9%) | 45 | +12.8 s | 894 (60%) | 0 | +9 |
| C | one | 696 | 8 (1%) | 0 | +3.1 s | 674 (97%) | 0 | +77 |
| C | giant | 917 | 13 (1%) | 0 | +4.2 s | 892 (97%) | 0 | +71 |
| C | twin | 1478 | 36 (2%) | 1 | +5.9 s | 1205 (82%) | 0 | +52 |

Most of B's longer flights are its own trade: at its TIME_W of 1, B's flight
costs less than A's (29 of 37 one sun, 48 of 63 giant, 105 of 131 twins). There
A took a quick, costly flight. Where A's flight fits inside B's cap and would
cost less at TIME_W 1 but B flew longer, B's search missed it: 6, 7 and 22 game
starts. C's longer flights are few (1 to 2%) and short (worst +5.9 s).

SolveTest's plans, the same comparison:

| setting | sweep | both clean | longer than A (over 0.3 s) | worst | extra engine work, median px/s | a cheaper flight A finds inside the cap, missed |
|---|---|---|---|---|---|---|
| B | one | 3869 | 264 (6.8%) | +14.2 s | +8 | 282 (7.3%) |
| B | giant | 4647 | 437 (9.4%) | +14.3 s | +6 | 522 (11.2%) |
| B | rtwin | 3024 | 322 (10.6%) | +13.1 s | +12 | 396 (13.1%) |
| B | twin | 1080 | 100 (9.3%) | +16.7 s | +0 | 150 (13.9%) |
| B, dials alone | one | 3869 | 268 (6.9%) | +14.2 s | +8 | 282 (7.3%) |
| B, dials alone | giant | 4646 | 439 (9.4%) | +14.3 s | +6 | 522 (11.2%) |
| B, dials alone | rtwin | 3023 | 376 (12.4%) | +26.3 s | +12 | 398 (13.2%) |
| B, dials alone | twin | 1080 | 103 (9.5%) | +16.7 s | +0 | 150 (13.9%) |
| C | one | 3869 | 53 (1.4%) | +7.7 s | +79 | 125 (3.2%) |
| C | giant | 4647 | 55 (1.2%) | +5.9 s | +74 | 169 (3.6%) |
| C | rtwin | 3024 | 115 (3.8%) | +4.7 s | +64 | 96 (3.2%) |
| C | twin | 1080 | 32 (3.0%) | +5.9 s | +32 | 54 (5.0%) |
| C, dials alone | one | 3869 | 59 (1.5%) | +7.7 s | +79 | 125 (3.2%) |
| C, dials alone | giant | 4646 | 65 (1.4%) | +5.9 s | +74 | 169 (3.6%) |
| C, dials alone | rtwin | 3015 | 156 (5.2%) | +12.5 s | +66 | 102 (3.4%) |
| C, dials alone | twin | 1080 | 42 (3.9%) | +15.1 s | +32 | 54 (5.0%) |

The last column is the review's own measure: A's flight fits inside the
setting's cap and costs less at the setting's TIME_W than what the setting
picked. With the as-built guesses kept it fell from 13% to 7% one sun and from
17% to 11% with a giant, but less in twins (real twins 15% to 13%, built twins
17% to 14%). The fallback does not touch it. The likely cause, not tested: the
search re-solves only the six rough conics that look cheapest at its own
TIME_W (CONIC_KEEP), so a flight A reaches from a conic B ranks lower is never
tried.

## The grid

The first look (FlightLen explorer, 3 seeds, 1,040 game starts a setting) was
made before the review, with the scaled guesses only and no fallback. Its rows
are the dials alone. "lost" counts flights A finds that the setting misses.
TIME_W and T_CAP are given first. Rows marked (2 seeds) are from the first
grid, 674 game starts.

| setting, dials alone, scaled guesses only | one sun, place to place | two suns, every game start | lost |
|---|---|---|---|
| A 0.5, 30 (as built) | 24.5 / 29.6 / 30.3 | 24.3 / 29.6 / 57.5 | - |
| 0.5, 24 (2 seeds) | 23.2 / 23.9 / 24.3 | 21.3 / 24.0 / 45.7 | 0 |
| 1, 24 (2 seeds) | 19.9 / 23.8 / 24.2 | 21.2 / 24.0 / 45.7 | 0 |
| 1, 23 (B's dials, wider search to 40) | 19.3 / 22.8 / 23.3 | 21.3 / 23.1 / 43.9 | 0 |
| 2, 23 | 18.9 / 22.8 / 23.3 | 21.0 / 23.0 / 39.9 | 0 |
| 1, 23, as-built guesses only | 18.5 / 19.0 / 21.7 | 18.6 / 22.5 / 38.0 | 0 |
| 8, 16 | 13.3 / 16.3 / 24.5 | 15.8 / 23.5 / 33.3 | 0 |
| 16, 16 (C's dials) | 11.3 / 15.1 / 20.2 | 13.9 / 20.4 / 34.5 | 0 |
| 32, 16 | 10.6 / 14.8 / 19.1 | 13.9 / 19.3 / 34.5 | 1 |
| 16, 15 | 11.1 / 15.1 / 20.2 | 13.9 / 20.4 / 34.5 | 1 |
| 8, 14 | 13.5 / 14.3 / 24.5 | 14.1 / 23.6 / 33.3 | 1 |
| 8, 12 | 12.1 / 18.5 / 24.5 | 12.3 / 23.6 / 33.3 | 6 |
| 16, 12 | 10.8 / 18.5 / 20.2 | 12.2 / 20.4 / 34.5 | 8 |

The same grid again with the settings as they stand now (both guess lists, the
fallback):

| setting | one sun, place to place | two suns, every game start | lost | longer than A (over 0.3 s), all game starts | extra engine work, median px/s |
|---|---|---|---|---|---|
| A | 24.5 / 29.6 / 30.3 | 24.3 / 29.6 / 57.5 | 0 | - | - |
| B | 18.9 / 22.8 / 23.3 | 21.3 / 23.1 / 57.5 | 0 | 85 of 1037 (8%) | +10 |
| C | 11.1 / 15.0 / 20.2 | 13.9 / 20.7 / 57.5 | 0 | 23 of 1037 (2%) | +63 |

The two-sun worst is 57.5 s in all three: a two-leg flight, flown by the
as-built search. FlightTest's and SolveTest's bigger sets showed losses where
this grid showed none, which is why the fallback is needed.

## Full runs of FlightTest and SolveTest

All run alone, through the lock: A from 10:03Z to 10:41Z, B and C from 11:02Z
to 11:39Z.

| | A, as built | B, your v2 pick | C, quick |
|---|---|---|---|
| **one sun**: found and clean, game starts | 694/696 | 694/696 | 694/696 |
| one sun: put there (game starts / all) | 0 / 0 | 0 / 0 | 0 / 0 |
| one sun: today's-planner fallbacks | 18 | 18 | 13 |
| one sun: click to settled, place to place (med / p90 / worst) | 23.5 / 29.6 / 30.6 | 18.9 / 23.0 / 23.7 | 10.8 / 14.9 / 20.0 |
| one sun: click to settled, every game start | 27.1 / 29.8 / 30.6 | 22.1 / 23.1 / 29.9 | 13.4 / 18.3 / 27.3 |
| one sun: game starts longer than A's (over 0.3 s) | - | 5% (worst +11.6 s) | 1% (worst +3.1 s) |
| one sun: engine work, median px/s | 91 | 104 | 157 |
| one sun: planning ms (median / worst) | 15 / 339 | 14 / 539 | 15 / 535 |
| one sun: corners (game starts, zoom 1/2) / S-bends | 0/0 / 2 | 0/0 / 1 | 0/0 / 0 |
| **heavy giant**: found and clean, game starts | 917/917 | 917/917 | 917/917 |
| heavy giant: put there (game starts / all) | 0 / 0 | 0 / 0 | 0 / 0 |
| heavy giant: today's-planner fallbacks | 22 | 20 | 15 |
| heavy giant: click to settled, place to place (med / p90 / worst) | 22.3 / 29.5 / 30.8 | 18.9 / 23.0 / 23.7 | 11.3 / 15.5 / 28.2 |
| heavy giant: click to settled, every game start | 24.5 / 29.8 / 39.5 | 21.8 / 23.1 / 36.4 | 13.3 / 18.0 / 34.4 |
| heavy giant: game starts longer than A's (over 0.3 s) | - | 7% (worst +10.1 s) | 1% (worst +4.2 s) |
| heavy giant: engine work, median px/s | 93 | 101 | 157 |
| heavy giant: planning ms (median / worst) | 16 / 307 | 15 / 489 | 15 / 485 |
| heavy giant: corners (game starts, zoom 1/2) / S-bends | 0/0 / 0 | 0/0 / 0 | 0/0 / 0 |
| **two suns**: found and clean, game starts | 1478/1478 | 1478/1478 | 1478/1478 |
| two suns: put there (game starts / all) | 0 / 24 | 0 / 24 | 0 / 24 |
| two suns: today's-planner fallbacks | 2 | 2 | 2 |
| two suns: click to settled, place to place (med / p90 / worst) | 19.5 / 29.7 / 47.0 | 18.7 / 23.1 / 47.0 | 13.1 / 16.5 / 47.0 |
| two suns: click to settled, every game start | 24.4 / 29.8 / 57.8 | 21.5 / 23.3 / 57.8 | 14.0 / 21.1 / 57.8 |
| two suns: game starts longer than A's (over 0.3 s) | - | 9%, 45 by over 5 s (worst +12.8 s) | 2%, 1 by over 5 s (worst +5.9 s) |
| two suns: engine work, median px/s | 96 | 104 | 161 |
| two suns: planning ms (median / worst) | 43 / 503 | 41 / 742 | 45 / 734 |
| two suns: corners (game starts, zoom 1/2) / S-bends | 0/0 / 3 | 0/0 / 5 | 0/0 / 1 |
| two suns: flights in two legs, click to settled (med / worst) | 37, 46.2 / 57.0 | 31, 47.0 / 57.0 | 30, 47.0 / 57.0 |
| far places: far one | 262 plans, 258 solved, 4 today's, 0 put there | 262 plans, 258 solved, 4 today's, 0 put there | 262 plans, 258 solved, 4 today's, 0 put there |
| far places: far twin | 332 plans, 332 solved, 0 today's, 0 put there | 332 plans, 332 solved, 0 today's, 0 put there | 332 plans, 332 solved, 0 today's, 0 put there |
| far places: core | 70 plans, 70 solved, 0 today's, 0 put there | 70 plans, 70 solved, 0 today's, 0 put there | 70 plans, 70 solved, 0 today's, 0 put there |
| far places: start | 24 plans, 24 solved, 0 today's, 0 put there | 24 plans, 24 solved, 0 today's, 0 put there | 24 plans, 24 solved, 0 today's, 0 put there |
| SolveTest one: found and clean | 3869/3888 (99.51%) | 3869/3888 (99.51%) | 3870/3888 (99.54%) |
| SolveTest one: plan time s (med / p90 / worst) | 24.5 / 29.1 / 39.0 | 22.2 / 22.4 / 39.0 | 11.5 / 15.5 / 37.9 |
| SolveTest one: engine work px/s, median | 47 | 60 | 137 |
| SolveTest one: planning ms (med / worst) | 15 / 209 | 13 / 391 | 13 / 356 |
| SolveTest giant: found and clean | 4647/4656 (99.81%) | 4647/4656 (99.81%) | 4647/4656 (99.81%) |
| SolveTest giant: plan time s (med / p90 / worst) | 24.0 / 29.1 / 33.1 | 21.2 / 22.4 / 32.3 | 11.5 / 15.5 / 33.1 |
| SolveTest giant: engine work px/s, median | 52 | 63 | 138 |
| SolveTest giant: planning ms (med / worst) | 15 / 235 | 14 / 424 | 13 / 401 |
| SolveTest rtwin: found and clean | 3024/3024 (100.00%) | 3024/3024 (100.00%) | 3024/3024 (100.00%) |
| SolveTest rtwin: plan time s (med / p90 / worst) | 24.0 / 29.1 / 57.2 | 21.3 / 22.4 / 57.2 | 13.7 / 20.2 / 57.2 |
| SolveTest rtwin: engine work px/s, median | 83 | 97 | 158 |
| SolveTest rtwin: planning ms (med / worst) | 41 / 510 | 39 / 768 | 41 / 751 |
| SolveTest twin: found and clean | 1080/1080 (100.00%) | 1080/1080 (100.00%) | 1080/1080 (100.00%) |
| SolveTest twin: plan time s (med / p90 / worst) | 17.1 / 28.7 / 29.9 | 15.4 / 22.4 / 26.7 | 10.6 / 15.6 / 28.5 |
| SolveTest twin: engine work px/s, median | 56 | 64 | 102 |
| SolveTest twin: planning ms (med / worst) | 47 / 237 | 45 / 336 | 42 / 369 |
| SolveTest verdict | PASS | 1 FAILURES: and no kept flight past the warm slack of both a fresh search and its own old cost (1) | 1 FAILURES: rtwin: no burn swings the ship round a point, its speed under 5 px/s mid-burn (a cusp as drawn), out of a ring, a settled star orbit or alongside: 1 of 2610 |

Today's planner from the same clicks, as main flew it (A's run), click to settled (med / p90 / worst): one sun, place to place 6.9 / 9.7 / 12.1 s, every game start 6.8 / 9.6 / 12.1 s; with a heavy giant 7.2 / 10.4 / 12.5 s and 6.8 / 10.1 / 12.5 s.

Notes on the table:
- B and C plan in about the same median time as A. Their worst plans (734 to
  768 ms in twins, against A's 503 to 510) are two-leg flights or fallbacks
  where both searches run, planned on a worker.
- "put there / all" counts the harness's free and close-by starts too. Every
  one of those is the same list in A, B and C.
- C's engine work is about 1.7 times A's.
- Today's planner never flies in a twin, so it has no two-sun numbers.

## The eight replays, click to settled (s)

Seed 4242. The one-sun system is 18 (IOTA HOLLOW-4), at zoom 0.3447. The twin
is 116 (ETA CALLOUS WATCH), at zoom 0.2398 (its own fit is 0.2389; the map
keeps the nearer zoom). Each flight is flown from ten selection moments 0.1 s
apart, its preview drawn then and a click 0.5 s later. The run shown is the one
nearest each setting's median, and the range is the fastest to the slowest of
the ten where they differ by 0.2 s or more. The data is in replays.json.

| flight | from | to | A | B | C | today's |
|---|---|---|---|---|---|---|
| one-neighbour | in orbit of IOTA HOLLOW-4 II (DESERT) | IOTA HOLLOW-4 IV (SHATTERED WORLD) | 29.0 | 22.5 (22.4 to 23.1) | 16.0 | 11.2 |
| one-across | in orbit of IOTA HOLLOW-4 I (GRAPHITE WORLD) | IOTA HOLLOW-4 IV (SHATTERED WORLD) | 29.5 (28.8 to 29.6) | 22.9 | 13.9 | 10.1 |
| one-starorbit | a settled star orbit, 625 px out | IOTA HOLLOW-4 IV (SHATTERED WORLD) | 29.7 | 23.3 | 16.1 | 5.7 |
| one-edge | just arrived by jump: a settled star orbit, 681 px out | IOTA HOLLOW-4 II (DESERT) | 29.5 | 23.0 | 15.1 | 5.2 |
| twin-AtoB-worlds | in orbit of ETA CALLOUS I (DESERT) | ETA CALLOUS II (ROCK) | 19.7 (16.9 to 28.9) | 18.5 (7.1 to 20.4) | 9.1 (7.0 to 13.9) | none |
| twin-world-to-starB | in orbit of ETA CALLOUS IV (VIOLET GIANT) | ETA CALLOUS WATCH B | 30.4 (23.5 to 30.5) | 19.6 (16.6 to 22.7) | 15.6 (15.5 to 16.5) | none |
| twin-starA-to-starB | in the close orbit of ETA CALLOUS WATCH A | ETA CALLOUS WATCH B | 12.1 (8.7 to 16.2) | 11.5 (8.7 to 20.0) | 9.4 (8.3 to 12.8) | none |
| twin-circumbinary-to-S | in orbit of ETA CALLOUS V (ROCK) | ETA CALLOUS I (DESERT) | 29.5 (28.4 to 29.5) | 22.9 (22.5 to 23.2) | 15.8 | none |

**One-edge, fixed after a second review (Nov 1).** The first one-edge replay
started in the wrong place. The harness opens the map headless, and headless
`SystemView.show_system` returns before its first await. So
`SystemMapScreen.show_system` worked out the arrival point before the frame
had a size: the window ended at the star, and
`ex = minf(edge, (window.end.x - CX - 26) / zoom_min)` came out at -26 / zoom,
the point (-75, -210). Its arrival orbit (`arrival_r`) was 159 px from the sun,
inside world I. In the game the sky's bake awaits frames, so by then the frame
is laid out (655 x 420, the window from (156, 61)), and the same line gives
min(930, (811 - 480 - 26) / 0.3447) = 885: the point (885, -210), 909 px out,
past world IV's 807 px orbit. `arrival_r` keeps the arrival orbit clear of
world IV's ring, so the ship arrives on a settled star orbit 681 px out,
between the belt and world IV. One-edge now starts there, with the same target.
The new times are inside the spread of FlightTest's 146 one-sun arrival starts
(medians 29.3 / 22.8 / 17.9 / 7.5 s): A and B sit at its 65th and 72nd
percentile, C and today's at its 14th and 21st. Over the ten moments each moves
by under 0.05 s. The other seven replays came out the same to the last digit.
The edge spreads quoted in the review table above and just below (C 10.8 to
12.7 s, today's 3.5 to 4.9 s) are from the old start. replays.json now also
gives every run the flame's length, the ring's drawn scale and the 1.4 s before
the click (its `note_added` says how).


The twin flights spread widely with the moment, so one twin replay says little
on its own about a setting: read the range. The one-sun flights move by under
1 s; from the fixed edge start, by under 0.05 s.

## What is still not clean

- **B:** one SolveTest replan check fails, as it did before the review. A
  preview planned again 3 s on keeps a flight 0.7 over its warm slack (114.8
  against its old 91.3; a fresh search finds 60.3): seed 7 node 329, star B to
  world 0. That slack was tuned at TIME_W 0.5.
- **C:** one SolveTest check fails, as it did before the review. In 1 of 2,610
  real-twin flights a burn slows under 5 px/s (a cusp as drawn). The study
  named it seed 4242 node 281, alongside a station to world 0; this log does
  not name it.
- **C:** in FlightTest, one harness free start gets a flight that runs 0.72 px
  into a keep-out (seed 4242 system 291, free to world 1). It counts as found
  but not clean, so the fallback never runs.
- **B** still flies over 5 s longer than A in 45 of 1,478 twin game starts
  (3 one sun, 7 giant). In most, A found a quick costly flight and B a slower
  cheaper one; in some, B's search missed A's.
