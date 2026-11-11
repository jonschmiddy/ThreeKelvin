The reasoning behind `tkg/scripts/ui/sysmap/ArriveSide.gd`; each heading is referenced from the code by a `Why:` line.

## Arrive side

**Nov 11: the choice was dropped.** Jon: "I think the light side/dark side is cool, but
it doesn't make sense. I think it adds too much noise... Let's just have the light side
and with its spin as the default. It's too much text on the box for a planet." So every
flight to a world now asks for the lit side, going round with its spin. Clicking the dark
half and holding Shift change nothing; the hover no longer reads a half (`side_at` is
gone), the tag has no side lines (`words` is gone) and the ring has no arc over the
picked half (`draw_half` is gone). `wish_now` still asks only while the selected world is
pointed at (the second click always is), and only of a world: belts and stations have no
lit side. The solver's ring target keeps `side` and `sense` as below; the map just always
hands it `side` +1 and the spin's sense.

What follows is the Nov 10 design as built, kept for the solver's half of it.

Jeremy (friends' alpha) asked to arrive on a chosen side of a world and to orbit with or
against its spin. Three ways to pick were filmed on the real map (tk-scratch/arrive-side,
Nov 10: S1 a spot on the ring, S2 draw the swoop, S3 click the lit or dark half) and Jon
picked S3.

What it is on the map:

- The world's own shading is the choice. The selected world's lit half (the half toward the
  light, as `SystemView.toward_light_of` shades it) and its dark half are two click targets:
  `SystemOverlay.hit` puts `side` on a world hit, from the pointer's place against that same
  light direction, so the half you click is the half that looks lit.
- Shift held, the ship goes round against the world's spin; let go, with it (`spin_sense`).
- The hover tag names both, in the game's plain voice: "LIT SIDE · WITH ITS SPIN" and under
  it "HOLD SHIFT: AGAINST ITS SPIN" (or "LET GO OF SHIFT: WITH ITS SPIN"), with the half
  marked by an arc on the hover ring. The lines show only while a second click would fly
  there (the world selected, the ship able to leave its orbit, not already there).
- The flow is today's: one click selects, the second flies. The second click carries the
  side: `SystemMapScreen._step_ship` sets `ShipFlight.wish` every frame from the hover and
  Shift (`wish_now`), the preview's key carries it (`key`), so the line drawn is the line
  flown; `tap` reads the click's own half before flying, and `_fly` drops a drawn plan that
  is not the wish's (`plan_matches`) and plans afresh.
- Nothing pointed at (the pointer off the world), no wish: the autopilot arrives as it
  likes, as before. Belts, stations and the other alongside places have no halves.

In the solver the ring target gains `side` (+1 lit, -1 dark) beside the `sense` it already
took; `FlightSolve._price` throws out any arrival whose ring angle is not `SIDE_IN` (cos
0.15, 8.6 deg) into the half asked, and the choice records the side (`sd`), so a kept choice
never replays for another side. The margin is so an arrival reads on its half as the light
drifts a little over the flight, and never sits on the terminator.

What it costs (ArriveSideTest, Nov 10, CURVED at x12, 6 one-sun systems over seeds 4242
and 7, 40 flights an ask): asking a side adds a median 0.00 s to the click-to-arrival time,
p90 +0.0 to +0.5 s, with 1 to 2 flights in 40 over a second longer; asking a way round adds a
median 0.00 s, p90 +1.0 to +1.2 s, 3 to 7 in 40 over a second longer. Every ask was found
and flown clean (100%), the same as free. The fast flights' arrivals were already near the
world's own direction of travel, and the half or way asked is reached by a small change
of the arrival angle, not by a longer coast.

## Spin sense

"With the spin" is a rail direction. The rail counts +1 as the plane's angle growing
(`ShipFlight.start_rail`: `ang` increases with `dir` 1), which is clockwise on screen and the
way every world goes round its star (`SystemLayout.Body.point3`: `phase + t / period`).
`planet.gdshader` turns the globe by `seed + time * spin` about its screen-up axis, so for a
spin over 0 its near face moves left on screen, which is the same clockwise turn. So:

- an ordinary world (spin over 0): with the spin is `dir` +1;
- a BACKWARD world (`spec.spin` under 0; the facts say "BACKWARD"): with the spin is -1,
  and the tag says "WITH ITS SPIN (BACKWARD)";
- a LOCKED world (`spec.spin` 0, one face to its star): it turns once an orbit, the orbit's
  way, so with the spin is +1 and the tag says "WITH ITS ORBIT (LOCKED)".

The spin is read off the world's drawn spec (`PlanetView.spec`, the view's own), or
`Worlds.spec` when no view holds it.

## When no flight reaches the side

The solver throws out arrivals on the wrong half, so an ask could find nothing where a free
flight would. It has not happened in the sweeps (100% found, one sun and two), but the map
must never get worse for it: `ShipFlight.make_plan` and `plan_bg` solve again with the
side let go (`unsided_solve`, the sense kept) before falling to today's planner, and mark
that choice `sdx` with the side it stands in for, so `plan_matches` still takes the line
drawn as the click's and does not plan it a third time.

## The light in a twin

With one sun the lit half is toward the world's host, which the solver knows at every
moment (`_tgt_at`'s angle plus pi). With two suns `SystemView.toward_light_of` blends the
two by their shares, and the pair turns, so the half moves faster than a one-sun world's
and the solver cannot read the shader's rule. The wish hands it the light's way at the
map's t (`lit`), how fast it turns (`lit_w`, read over half a second) and when (`lit_t`);
`FlightSolve._side_ok` carries it to each arrival's time. Before that the twin sweep landed
3 of 48 sided flights up to 9 deg over the terminator; with it, none.
