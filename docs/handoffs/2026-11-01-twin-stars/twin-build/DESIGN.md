# Twin stars and heavy giants: the build design (ruling 20, Oct 30)

Jon, Oct 30, from the Twin Stars Prototype page: "Prototype: twin:A giant:A.
We have time to build the twins, so why not." And: "I picked heavier giants
being 1/4 - 1/10 purely because it's more fun."

So the game gets:
1. **Two-star (binary) systems**, with worlds round each star and round both.
2. **An autopilot that solves its flights** under the real pull of the stars
   and the giant on map time (Phase 13 step 2's solved flight, ruled Oct 29
   "flight:N clock:map", which the twins need). This applies in every system.
3. **Giants at 1/10 to 1/4 of their star's mass**, which every autopilot
   flight feels.

Standing rules this build must keep:
- **WASD flying stays gravity-free.** Jon, Oct 3: the sun's pull made flying
  "clumsy and awkward". Only autopilot flights feel the bodies.
- **Flying inside a system costs no fuel.** Engine work only picks the path.
- **Co-op partner places keep working.** `Net.report_spot` sends offsets
  from the orbited world.
- **The path stays smooth at the game's pixel scale.** No corners or cusps
  (Jon: "why are there sharp angles on some of the trajectories?").
- **Clicking never loses anything.** Fly, then orbit, then open.

Read first:
- the readers' maps in `understand/` beside this file (flight.md, layout.md,
  drawing.md, sites.md, tests.md), with file:line touchpoints;
- the prototype `tk-scratch/pages/twin-stars/README.txt` and its `src/`.

## Wave 1, as built (Oct 30). Read this first: it overrides the lines below where they differ

feat/twin-stars now holds the merged wave 1: the layout (5527d617, a10c7210)
and the solver (09057bbe, 915d4881), merged as 6685698d. The reports are in
`wave1/` beside this file (layout.json, planner.json).

**The layout (SystemLayout, MapGen, SaveGame, NetSession print, SystemTest):**
- Twins: ORDINARY SYSTEM nodes, 213 of 855 eligible (25%) over the four
  systemtest seeds. `-- twin=all` / `twin=none`, or `MapGen.twin_force`
  (1 all, -1 none) from a harness. One-sun layouts are identical to main's,
  1,406 of 1,406.
- Star A's share is **0.52 to 0.58** (not 0.65: above 0.58 the pairs ran
  away). The separation is 320 to 380 px, and star B lies within 40° of level.
  Star B's radius is 11.6 to 15.
- **`L.fit_zoom`** (every system): the zoom the layout was fitted to. It is
  `SystemLayout.open_zoom(edge)` with no job and no Hellbender. A job or the
  Hellbender never changes it. `SystemLayout.open_zoom(edge)` repeats
  `SystemMapScreen._fit_zoom`'s formula on its 655×420 fallback frame. Keep
  the two in step.
- **The twin star ladder.** Let D be the star's drawn sun in plane px at
  fit_zoom.
  - `keep_clear_of(p)` = max(r + 10, D + 6). This is the solver's keep-out.
  - `star_rail_of(p)` = keep + 2. This is **the close orbit a ship rides**.
  - `star_ring_of(p)` = keep + 4. This is the capture ring.
  - One-sun values are unchanged: 48 / 60 / 95.
  - **In a twin, today's ride at `star_ring() − 8` is inside the
    keep-out.** Ride at `star_rail_of(p)`. The radii derived from the rail
    (bumper rail + 25, rmin r + 30, rmax ring − 4) need twin values.
- **Bodies.** The first planet circles A (`host` ZERO, `host_id` -1). The
  second circles B (`host` star2_at, `host_id` STAR_B). Both have soi
  (ring) 20, and each sits at 0.70 to 0.90 of its Holman-Wiegert limit.
  Everything else circles `bary` (`host_id` -9) at least 2.517 × sep out,
  with its normal `soi_of` ring. That includes the jobs and the Hellbender.
  `edge` is measured from star A. Index order is not radial order.
- New statics:
  - `s_limit(mu)` and `p_limit(mu)`;
  - `open_zoom(edge)`;
  - `sun_drawn(r, z)` = sqrt((r z)² + 10²) game px;
  - `world_drawn(b, z)`;
  - `held_most(raw, least)`, which copies `SystemView._held`'s 2 px blocks
    with HOLD_PX 1.4. **If SystemView's sun sizing changes, these follow.**
- New per-body helpers: `light_distance(b)` and `zone_of(b)`. Zones go by
  the light, so a twin's S-type worlds are always the hot zone (zone 0), and
  a twin never has a city world. This is for Jon to rule on, not a bug.
- Heavy giants: every giant in every system has `gm_frac` in [0.10, 0.25]
  and `gm = gm_frac × GM_SHIP`. Mass and soi are unchanged.
- Opening zoom: one sun has a median of 0.345. Twins have a median of 0.254
  and a least of 0.230. A twin's worlds are drawn smaller.

**Open from the layout, assigned:**
- **DRAWING: a job or the Hellbender out past a twin's edge.** The map then
  opens below fit_zoom, and the suns' 10-px floor draws them wider than the
  rings were fitted to. Worst case with all three out: 184 rings up to 2.5 px
  inside the drawn sun, and 550 worlds touching it. Fix it in drawing: **in
  a twin, below fit_zoom the sun's drawn plane radius never exceeds its
  drawn plane radius at fit_zoom**, so the floor shrinks with the zoom. Do
  not cap the zoom; the job's place must stay on screen.
- DRAWING: in front of its sun (the near point of its circle), an S-type
  world's disc overlaps the sun's disc by 5.6 to 10 game px at the opening
  zoom. That is a planet passing in front of its star. Make sure the depth
  order draws it in front there and behind on the far side. One-sun inner
  worlds do the same.
- DRAWING: a ship riding an S-type world's 20 px ring sits 17.6 plane px out.
  That is about 4.4 game px at zoom 0.25, which is inside the world's 5 to
  6 px drawn disc at the opening zoom. Measure it and show it in the stills.
  Propose a fix (ship drawn on top with an outline, a smaller ship mark, or
  the map zooming in on an orbited world), but leave the ruling to Jon.
- FLIGHT: 30% of the bodies round both stars sit inside another world's ring,
  29% inside the giant's (one sun: 13%). ShipFlight captures the **first
  world by index** whose ring holds a slow ship, so letting go near a
  derelict by the giant puts the ship on the giant. Capture the nearest
  whose ring holds it (or the one the ship is flying to). This helps one-sun
  systems too.
- Readers of "the centre is the origin" in files the layout did not own:
  - SkyWeather._p_comet (:1534) takes the smallest orbit as the inner orbit
    about the origin (DRAWING);
  - LocalSky._situate (:1514-1521) measures orbit_d as p.length() from star
    A, so a world round B reads as about 350 px out (DRAWING: use the
    distance from its own host star, or `L.light_distance`);
  - LocalSky:874 and SystemView:1332 build `_bubble_r` from b.orbit ± 28
    about the origin (DRAWING);
  - SystemView:931's ORBIT readout gives AU about the body's own host
    (DRAWING: say which star, or "both");
  - ShipFlight:288's belt centre and :869's `arrival_r` (FLIGHT);
  - FlightTest's starts (FLIGHT).

**The solver (MapGravity, FlightSolve, SolveTest):**
- `MapGravity.from_layout(L)`: pure data, shareable across threads.
  - `acc(x, z, t)`, `margin(x, z, t)`, `giant_at(k, t)`.
  - `keep_out_star(L, p)` is measured at `L.fit_zoom`. In a twin it equals
    `L.keep_clear_of(p)`.
- `FlightSolve.solve(G, dep, tgt, t, prefer = {}) -> Result` (static,
  deterministic, safe on a worker). The API is documented at the top of
  FlightSolve.gd. Read it there.
  - **A star's close orbit as a radius:** `FlightSolve.star_orbit_r(L, p)`.
    It returns the rail in a twin and ring − 8 for one star. Never pass
    ring − 8 in a twin.
  - **LEAD_MAX is 4.4 s, not 2.2.** The ride goes at the ring's own pace for
    up to 4.4 s, then phases with lead_k up to about 2.6, holding the push to
    THRUST and the speed to 98. ShipFlight's `rail.phase {T: lead, k: lead_k}`
    flies it as it is.
  - **Alongside departures** hold at place + off for `Result.lead` (KEEP_HOLD
    1 s), then leave.
  - **A preview must be the flight flown.** Pass the preview's
    `Result.choice` back as `prefer`:
    - a ring departure replays exactly while its departure is still ahead;
    - an alongside one while its hold is not over;
    - a free one only at the same moment and state.
    So fly the preview's own Result where the click comes before its
    departure, and re-plan an alongside or free preview at least once a
    second.
  - `found == false` on under 1% of plans: keep a fallback, today's planner
    or a placed arrival.
- **Measured on this Mac (merged tree, 10,362 plans):**
  - Found and clean:
    - one star: 99.97%;
    - heavy giant: 100%;
    - the layout's own twins: 99.16%;
    - hand-built prototype twins: 98.9%.
  - Planning time:
    - one star: median 13 ms, worst 61 ms;
    - giant: median 14 ms, worst 70 ms;
    - twins: median 37 ms, p99 83 ms, worst 136 ms.
  - **Over 25 ms, so plan twin previews (and, if simpler, every preview) on
    a WorkerThreadPool task.** The worker gives identical results, 1,600 of
    1,600. The line arrives a few frames later; the ship keeps riding
    meanwhile.
  - Flights: median 24 s one star (T_CAP 30), 22 s in twins. Engine work:
    median 38 px/s one star, 74 in twins. `TIME_W` 0.5 is Jon's dial.
  - Landing is exact: worst 0.0001 px, under 0.07 px/s.
- **FLIGHT: `ShipFlight.center()` for belts ignores `Body.host`.** Of the
  real-twin belt arrivals, 236 land more than 0.5 px off the beacon. Make it,
  and `arrival_r`, host-aware.
- SolveTest takes 360 s in full. With `only=` and `lineups=` it runs shorter.
  Whether it joins the gate is the orchestrator's decision.

## Fixed decisions (the contract)

### The frame
- **Star A stays at the plane origin, as the one star always was.** Star B
  holds still at `L.star2_at`.
- **The stars do not move.** On map time the pair turns once an hour, and
  every map visit restarts the clock at 0, so the stars would jump back.
- This keeps every "star at the origin" assumption true for star A:
  - `center(-1)`;
  - co-op's absolute -1;
  - the home glide;
  - `LocalSky._situate`'s p.length().
- Star B is new everywhere.

### Place ids
- A place is an int:
  - body index ≥ 0;
  - -1 = star A;
  - **`SystemLayout.STAR_B` = -4 = star B**.
- -2 is none, -3 is the edge, -9 is open space, -10 is a co-op arrival and
  -99 is SITE_ANY. Their meanings do not change.
- **Test with `SystemLayout.is_star(p)` and `SystemLayout.is_place(p)`,
  never with `>= -1` or `< 0`.** About 45 sites use those idioms (see sites.md
  and flight.md). Convert each one you own, and keep its meaning for
  everything that is not star B.
- Star A keeps every star event: `star_beacons`, `site = star` and the
  `needs_star` gate. Star B holds no events. Twins are ORDINARY stars only,
  so no star event can roll there anyway.

### The data (committed on feat/twin-stars as fcc32a6c)
`SystemLayout` has:
- `GM_SHIP 208250`, `GM_KEPLER 61.685`, `KAPPA 3376`;
- `GIANT_MIN 0.10`, `GIANT_MAX 0.25`, `STAR_B -4`;
- `twin`, `star2`, `star2_r`, `star2_at`, `star_share` (star A's share of
  the mass), `bary`, `sep`;
- `is_star`, `is_place`, `stars()`, `star_pos(p)`, `star_radius(p)`,
  `star_kind_of(p)`, `star_gm(p)`;
- **`star_rail_of(p)`, `star_ring_of(p)` and `keep_clear_of(p)`**: each
  star's close orbit and keep-clear, one source for the layout and the
  flight. The layout fills `_rail` and `_keep` in a twin.

`Body` has:
- `host` (the centre of its circle);
- `host_id` (-1 star A, STAR_B star B, -9 both);
- `gm` (the pull a ship feels, in px³/s²);
- `gm_frac` (a giant's weight against its star or stars).

`Body.orbit_point(a)` now circles `host`. **At least 12 places copy the
orbit maths about the origin instead of calling the Body.** Each must add
`host`. The list is in layout.md's risks and drawing.md's touchpoints.

`MapGen.MapNode.twin` is a bool, default false.

### Physics on map time
- **The total star GM a ship feels is `GM_SHIP` = 208,250 in every system,
  of every star kind.** The worlds' Kepler GM is the same for every kind
  today, since the period formula has no mass in it.
- In a twin, star A has `star_share` of it and star B the rest.
- A giant pulls with `gm = gm_frac × GM_SHIP`. It moves on its circle during
  a flight, and that motion is analytic and cheap, so include it. Stars are
  fixed.
- Worlds, stations and belts pull nothing.
- The ship's thrust is 40 px/s² (`ShipFlight.THRUST`), and burns are finite
  at that thrust.
- Ships leave and join a world's ring at `RAIL_V` 35 px/s relative to the
  world, either way around.
- Map-time flights take roughly 8 to 30 s. Jon picked v2's flight, which
  took 18 to 23 s. Today's flights are time-scaled conics of 4 to 12 s that
  reach 950 to 1,200 px/s; that ends.

### Twin layout (the layout agent owns the numbers; these are the bounds)
- **Which nodes:** ORDINARY SYSTEM nodes only. Not START, STATION, PULSAR,
  CORE, RED or BLUE.
  - About **1 in 4** of the eligible ones.
  - Rolled with `Rng.derive(&"twin", n.index)` at generation. Never use a
    shared stream; `systemtest` and `rngtest` hold that.
  - Saved on the node (SaveGame VERSION 38, a missing value means false).
  - Cleared when `_seed_pulsars` turns a node into a pulsar.
  - Hashed into `NetSession.galaxy_print`.
  - **A harness switch, `-- twin=all`,** makes every eligible node a twin,
    so every agent can test on twins. A harness can also set `n.twin = true`
    before calling `SystemLayout.of(n)`.
- **The stars:**
  - Star A's share `star_share` rolled in [0.52, 0.65].
  - Separation `sep` rolled in about [300, 380] px.
  - Star B at angle θ, rolled.
  - `bary = (1 - star_share) × star2_at`.
  - Both stars ORDINARY. B is a little smaller: r about 16 × (share_B /
    share_A)^0.8.
  - All twin rolls come from the "twin" derive stream, never R. Draws on R
    before its current end would move every system.
- **S-type worlds round each star:**
  - Stability limit (Holman and Wiegert 1999, circular): a ≤ (0.464 −
    0.380 μ) × sep, where μ is the OTHER star's share. That gives 0.293
    round A and 0.255 round B at a 0.55 share.
  - Put each S-type world at 0.70 to 0.90 of its limit.
  - **Every twin has one world round each star** (the first two planets, or
    bare ones added). This is the twins' reason to exist: the flight from a
    world round A to a world round B, hooking round A and falling toward B.
  - S-type rings and the stars' close rings are smaller than today's, so they
    fit:
    - each star's close orbit inside its world's orbit;
    - each world's ring clear of its star's close ring by at least 8 px;
    - each world's ring clear of its star's keep-clear;
    - at the opening zoom, each world's disc clear of its sun's drawn disc
      (SystemView: sqrt((r z)² + 10²) game px).
  - Periods: `800 × (a/100)^1.5 / sqrt(share_host)`, plus the usual jitter.
- **P-type (circumbinary) bodies round `bary`:**
  - Orbit at least 2.423 × sep from the balance point (the limit is about
    2.42 for every share in range).
  - Today's period formula (total mass 1).
  - The giant, the belt and the station always go P-type, and so do every
    world after the two S-type ones.
  - The edge, the job places and the Hellbender's place take the host offset
    into account: the farthest reach is `|host| + orbit + reach`.
- **Radial order stops being index order in a twin.** The orbit gap check
  becomes a per-centre check, and nothing may silently rely on index =
  radius. Known users: edge, job, Hellbender, names, zones, SystemTest's gap
  check, ContractTest:328.
- Zones go by distance from the light, not by index.

### Heavy giants
- `gm_frac` rolled in [0.10, 0.25] with `Rng.derive(&"giant_mass", n.index)`,
  in every system with a giant, twin or not. `gm = gm_frac × GM_SHIP`.
- `mass` (the fabric dent) and `soi` (the capture ring) do NOT follow
  `gm_frac`. Orbits must not move in the roughly 45% of systems with a giant.
- Drawn: the giant's fabric well a little wider or deeper with `gm_frac`.
- Panel: a MASS line such as "1/6 OF ITS STAR".

### The autopilot (the planner and flight agents)
- **A new pure-CPU solver, `MapGravity` + `FlightSolve`** (new files, no
  Nodes, no textures):
  - safe on a `WorkerThreadPool` task (ThreadStress's rule);
  - deterministic: the same inputs always give the same plan.
- It plans a flight from where the ship is to a target place:
  - the ship may ride its current ring or orbit for a lead of 0 to about
    2.2 s first (`LEAD_MAX`);
  - a departure burn at thrust;
  - a coast integrated through the stars and the giant (the giant moving);
  - an arrival burn onto the target's ring, either sense, at `RAIL_V`
    relative (or alongside, for a keep).
- It returns samples in today's `FlightPlan` form: `samp` at `SAMPLE` 1/240
  s, `burns` per sample, `end` {body, p, v, a, ...}, plus a replayable
  `choice`, so the drawn plan and the flown plan are the same flight.
- **Cost:** engine work (Σ|Δv|, px/s) + `TIME_W` × seconds. `TIME_W` is a
  named dial Jon can tune (memory: "give him the dial").
- **Keep-out** for each star: the larger of `L.keep_clear_of(p)` and the
  sun's drawn radius at the system's opening zoom + 6 px, in plane px. For
  the giant: its r + 3. The prototype's best twin flight passed 24 px off
  star A's surface.
- **Targets on this Mac (Intel i5-8257U, the slowest machine that plays):**
  - a plan found and clean for at least 99% of (start, target, line-up)
    cases in FlightTest's sweep and in twin and heavy-giant sweeps;
  - planning median ≤ 25 ms;
  - planning worst ≤ 150 ms, or run on a worker while the ship rides its
    ring, the drawn line arriving a few frames later.
- The near hop (`_near_hop`, a short hop in a world's frame) and the
  insertion onto a ring (`insert_plan`) may stay kinematic. The coast between
  places becomes solved.
- `FlightTest` gets the new flights, a twin and heavy-giant sweep, and a PASS
  line.

### Flying by hand in a twin (the flight agent)
- **Each star is a soft bumper.**
- Letting go settles onto a circle:
  - round the nearer star, inside its S-zone;
  - otherwise round the balance point, at a radius that clears both stars.
- The pace is STAR_PACE times the Kepler pace there. Replace the settle's
  hidden central pull toward the origin with a pull toward the settle centre.
- Each star has a close-orbit ring: -1 and STAR_B. Use `L.star_rail_of(p)`.

### Drawing (the drawing agent)
- Star B is a second `SunView` at `star2_at`, a little smaller and visibly a
  different sun. Reuse `sun.gdshader`; no new shader, since every shader
  compiles cold on the Mac.
- **Lighting** uses one effective light per world: the flux-weighted
  direction and tint of the two stars. That keeps `planet.gdshader` as it is.
- The fabric: two star wells. The shadows: from the nearer or brighter star.
- The palette: star B's light included without overflowing the 72 entries.
- Orbit lines, belts and hit bands circle each body's `host`.
- LOCAL's side-on sky shows both suns, the far one smaller.
- The star chart marks twin systems.
- Show it, don't describe it: SystemShot/SystemSheet stills of twin systems
  for Jon.

### Places, panels, co-op, saves (the sites agent)
- Star B is a place everywhere a star is:
  - the overlay's hit, tip, status words and occlusion;
  - the panel's star head, with both stars, their facts, and FLY HERE to
    either;
  - `_restore_ship` and `_parked`;
  - `Run.site_here` and wrecks;
  - LOCAL's event drawer place line;
  - `things_here`;
  - Router's at_* checks (never let -4 or -2 match another).
- Co-op: star B is fixed, so a spot at -4 is absolute like -1. `PROTOCOL`
  goes to 13.
- Words follow the plain voice (`.claude/skills/encounter-prose` §0): "Two
  suns", the stars named "<system> A" and "<system> B".

## File ownership (each agent edits only its own files; merges are by me)

| Agent | Wave | Worktree / branch | Owns |
|---|---|---|---|
| LAYOUT | 1 | tk-wt/twin-layout, feat/twin-layout | `SystemLayout.gd` (generation), `MapGen.gd` (the twin roll, pulsars, `-- twin=all`), `SaveGame.gd` (node field), `NetSession.gd` (galaxy_print and PROTOCOL only), `SystemTest.gd`, `ContractTest.gd` if index=radius breaks it |
| PLANNER | 1 | tk-wt/twin-solve, feat/twin-solve | new `scripts/systems/MapGravity.gd`, `scripts/systems/FlightSolve.gd`, new `scripts/sim/SolveTest.gd` |
| DRAWING | 2 | tk-wt/twin-draw | `SystemView.gd`, `SunView.gd`, `SystemPalette.gd`, `PlanetView.gd`/`ShatteredView.gd`, the map's shaders, `LocalSky.gd` (and its LocalDust/LocalSubject/LocalLife star reads, plus `_situate`'s -4), `SkyWeather.gd`, `StarchartScreen.gd`'s Glyph, `MapPerfTest.gd` |
| SITES | 2 | tk-wt/twin-sites | `SystemOverlay.gd` (all but the plan-line drawing), `SystemPanel.gd`, `SystemMapScreen.gd` (all but `_fly`/`_step_ship`), `Router.gd`, `LocalEventDrawer.gd`, `SectorScreen.gd`, `HudBar.gd`, `StarchartScreen.gd`'s STAR row, `NetSession.gd` spots, `RunState.gd`, `Ash.gd`'s orbit maths, the site harnesses (WreckSiteTest, SaveTest, NetTest) |
| FLIGHT | 2 | tk-wt/twin-flight | `ShipFlight.gd`, `SystemOverlay.gd`'s `_draw_paths`/`_plan_line`/`_draw_line3`, `SystemMapScreen._fly`/`_step_ship`, `FlightTest.gd`, and the flight waits in OrbitWorldTest, DockFlyTest, SubjectTest and LocalEventTest |

## How every agent works
- **Godot, one at a time on this Mac** (Jon's order). Every run goes through
  `bash /Users/jon/Documents/GitHub/tk-scratch/godot1.sh tools/dev/godot.sh -t <secs> -C <your worktree> --headless --path tkg -- <flag>`,
  run from /Users/jon/Documents/GitHub/ThreeKelvin. The script queues
  behind other agents' runs; expect waits.
- **Never run Godot directly, never `validate.sh`, never `gate_land.sh`.**
  Never open a window: no `render.sh`, no windowed harness. A windowed run
  covers Jon's screen.
- `--import` once after any new `class_name`, through the same wrapper with
  `-t 1800`. Your worktree's `tkg/.godot` is already copied in.
- Run `-- parseall` and the gated harnesses your change touches. Read their
  logs for `^<label>: PASS` and for any
  `SCRIPT ERROR|Parse Error|Compile Error|^ERROR:`.
- **Nothing CPU-heavy alongside:** no numba or SciPy solver beside a Godot
  run. A quick Python check is fine.
- **Never read or write Jon's real profile**,
  `~/Library/Application Support/ThreeKelvinAlpha`.
- Indent with tabs, use static typing, and draw from named Rng streams only
  (tkg/CLAUDE.md). Comments in the repo's voice: plain, saying why, recording
  what was measured.
- **Commit in your worktree** on your branch, with clear messages ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Don't push,
  don't merge.
- **Report** what you built, the numbers you measured, every harness you ran
  and its result, what you could not do, and anything the other agents must
  know (an interface you changed, a field you added).
