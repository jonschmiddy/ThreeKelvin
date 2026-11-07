The reasoning behind `tkg/scripts/sim/ThreadStress.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Thread stress

Above `const IDS := ["custodian", "whale", "leviathan"]`:

```text
WORKER THREADS DO PURE CPU WORK ONLY, under load, headless:
  godot --headless --path . -- sheet=ThreadStress [secs=20]
The fight's off-thread jobs, run back to back in parallel the way the game
starts them -- a creature's or the Custodian's motion cut (`EnemySlot`), a
breakup cut ahead of a kill (`SectorScreen._prebuild_death`) and a wreck
warmed (`EnemyArt.warm_wreck`) -- while the main thread makes textures as
fast as it can: card art loaded fresh from disk (`Database.card_art`'s
`load`, uncached), pictures uploaded, controls made and freed. Every engine
error is counted (a `Logger`); there must be none.
Before Oct 14 the motion cut and the breakup made their textures, nodes and
materials on the worker, and this raced the main thread's textures:
"Attempting to initialize the wrong RID" on the worker, `Parameter "t" is
null` in `texture_2d_initialize` on the main thread -- 26 errors in 20 s
here alone, 64-94 in 90 s with three running at once; every run. Now the node is made on the main thread, the worker only
cuts (its textures owed, `OffThread`), and the take-in (`FaunaMotion.attach`,
`ShipBreakup.finish`) makes them; its slowest is printed (it is on the
frame a creature's motion or a breakup starts).
And A.S.H.'s glitched take while the hull fails (`Audio.ash_voice_prepare`):
its playback made on the main thread, the decode and the edits on a worker
(`VoiceGlitch.bake_placed`), the stream made from the bytes on the main thread
(`VoiceGlitch.from_pcm`); its slowest take-in printed too.
And the sector map's flight plans (ruling 20, Oct 30): `ShipFlight.plan_bg`
solves a flight (`FlightSolve` through `MapGravity`, arrays only) on a worker
while the ship rides on, makes its FlightPlan and its drawn insertion there
from a snapshot of the ship, and lays its line out (`lay_out`); `take_bg`
only takes it in. Two ships at once in a two-star system (the slowest
plans), from a world's ring to every other place in turn; a third in a
system of one star whose plans all go to today's planner, on the worker too
(`old_only`: as a flight the solver finds nothing for); a fourth clicking
through `fly_bg` (the preview's job taken over, its plan taken in after the
step), letting go with W while one is coming, and set up afresh mid-plan;
and a ship freed mid-plan every half second (its task reaped, not waited).
```
