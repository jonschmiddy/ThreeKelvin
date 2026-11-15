# LatentFixTest

## Latent fix test

Three bugs James found in sweep 2 and did not fix, each a possible change to the game, fixed on Jon's ruling 3A (Nov 14) and held here.

- `ShipFlight._old_plan` read `_high` from the last kept choice. When that choice was no longer clean and the plan fell through to the half-ellipse to the star (or the bare tangent coast), it returned with `_high` still set, and the next plan on the same live ship (`_fallback` plans on the live ship) read it before anything assigned it: a waypoint pushed out to 0.85 of the edge. The flag is now cleared right after the kept choice is tried.
- `SystemView._Moons.ring_slots` cached by world and drawn radius only, so asking for more moons at the same radius returned the shorter list and the moon loop indexed past it. The key now holds the moon count.
- `LocalSky._wx_place` placed weather in `Rect2(60, 50, 840, PLAY.x - 70)`, with `PLAY.x` 70: no height. Every shaft, shock and glitter sat on the line y = 50 and a jet never found a pillar tip in it, so LOCAL never showed a jet. The band now runs from 50 px to `PLAY.x`, where the play's grade starts. Visible: those events now spread over 20 px rows, and jets can appear.
