The reasoning behind `tkg/scripts/systems/GalaxyGen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Galaxy kinds

Above `const KINDS := [`:

```text
Which galaxy this run takes place in.

Pure presentation. Systems are laid out on rings by MapGen and placed on
rings by the chart, so the shape of the galaxy behind them can vary freely
without moving a single jump or changing a single fuel cost. That separation
is what makes fifteen of these cheap.

THAT SEPARATION WAS NEVER TRUE, and this note is what replaced the claim.
`MapGen` read the galaxy in two places: `ring_count()` took `squash` -- a
CAMERA ANGLE -- and made node population depend on it, and `hop_distance()`
measured in the same foreshortened space, so a tilted galaxy was a smaller
galaxy whose jumps were cheaper. Measured over 500 runs: 132 systems on a
Lenticular against 188 on a Round Elliptical, and a 33-point spread in win
rate that nobody authored.

Both are fixed rather than normalised away, because galaxies playing
differently is the point. `density` and `reach` below say it OUT LOUD, per
kind, and `squash` went back to being what its own docstring says it is.

AND NO KIND HAS A HOLE IN IT ANY MORE. Barred Ring Spiral (`ring = 0.34`)
and Collisional Ring (`ring = 0.52`) were the only two, and the hole was not
a picture: `MapGen.ring_radius` remaps every populated ring into the annulus
`[ring, 1.0]`, while the Core is drawn at the origin regardless. Measured
across four seeds each, the nearest system to the Core sat at 0.046..0.100
of the disc radius on every other kind, at 0.235 on the Barred Ring and at
0.397 on the Collisional Ring -- so the last jump of a run crossed four to
eight times more empty space than anywhere else, and the Barred Ring also
held the longest single link in the game at 1.363, sixty per cent past the
next worst.

They were replaced rather than retuned. A smaller hole is the same hole.

`ring` itself stays in the schema and stays applied, because the machinery
is correct and a future ring galaxy would want it -- but it would want the
hole to be PAINT ONLY, with systems filling the middle the way stars in a
real collisional ring still do. Nothing reads it at 0.0.

Content is data, not code: a new galaxy is a dictionary entry, and the
renderer already knows how to draw every field in it.

Fields:
  arms        0 for no spiral structure at all (ellipticals, irregulars)
  twist       radians of winding across the full disc; higher is tighter
  bar         fraction of the radius held by a straight bar, 0 for none
  squash      vertical foreshortening; 1.0 is face-on round, 0.3 is edge-on
  core_share  fraction of stars belonging to the concentrated population
  core_pow    falloff of that population; higher packs harder into the middle
  halo_pow    falloff of the extended population that reaches the rim
  spread      how far stars stray off the arm ridge
  chaos       positional noise; what makes an irregular irregular
  ring        inner radius of a hole, as a fraction; 0 for a filled disc
  bulge       radius of the burning core, as a fraction of the disc
  dust        falloff of the wash between the arms
  gas         how much star-forming material is left; scales nebulae,
              dust lanes and supernova remnants. Spirals are rich, the
              ellipticals and lenticulars that ran out are nearly bare
  tail        draw a tidal stream flung off one side
```

## Rolling a galaxy

Above `static func roll(kind: int, r: RandomNumberGenerator = Rng.world) -> Dictionary:`:

```text
One galaxy, rolled from a type.

KINDS holds the archetype; this returns a copy with every parameter nudged,
so two Grand-Design Spirals are recognisably the same kind of object and not
the same object. Rolled ONCE per run and stored on RunState, because the node
layout is derived from squash and twist — re-rolling per call would move the
systems out from under the player.
`r` defaults to the world stream. It is a parameter at all so that the
determinism test can roll a galaxy twice from two generators and compare,
without reseeding the run out from under everything else.
```

## Nebula names

Above `static func nebula_name(h: int) -> String:`:

```text
The clouds between the systems. Named from a hash rather than rolled, because
the chart rebuilds its star field whenever the panel resizes, and a landmark
that renames itself when you drag the window is not a landmark.

Half come out as catalogue entries and half as names people gave them, which
is how a sky actually reads: the ones anyone has looked at long enough to
describe got a name, and the rest got a number.
```

## Table fingerprint

Above `static func table_fingerprint() -> String:`:

```text
The kind table, as a string two peers can compare.

LIVES HERE RATHER THAN IN NetSession, and not only for tidiness. Two peers
with different `density` or `reach` values lay out DIFFERENT MAPS from the
same seed -- `MapGen.ring_count` and the position of every system read them --
so they must not agree on a fingerprint. But writing that loop inside
`content_fingerprint` meant `NetSession` grew the strings "density" and
"reach", and `version_guard.py` cannot tell a dictionary read from a wire key
in a file it is watching: it demanded a PROTOCOL bump for a change that moves
no wire shape at all.

Asking the table to describe itself is the better factoring regardless. The
guard going quiet is a consequence of the code being right, not the reason.
```
