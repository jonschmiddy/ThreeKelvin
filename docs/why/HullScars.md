The reasoning behind `tkg/scripts/systems/HullScars.gd`; each heading is referenced from the code by a `Why:` line.

## Hull scars

Jon, Nov 17, on the Korvan zero hulls: "Can we make the difference from C to S grade a bit
more dramatic? C is not messed up enough." The grade looks in `HullGrade` (grime blotches,
drips, faded band, kit removed) stepped the ramp a shade or two, which at game scale left a
C that read as an S in a darker room. Three ideas are on trial, picked by
`HullGrade.DRAMA`:

- GRIME: age. Soot from the engines forward, grime pooled along the belly, rust bleeding
  down from under seams and rivets.
- BATTLE: violence. Scorch marks, dents lit from above, holes plated over with odd plates,
  holes punched through.
- JUNKER: a cheap build. Whole panels swapped for mismatched ones, one or two torn off
  down to the frame, lighter grime and rust, a few patch plates, the windows flickering.

Every colour is still one the hull already has (a walk along its own ramps, its darker warm
colours for rust), so `-- sheet=GradeSheet`'s palette check holds. Alpha is never touched:
the silhouette, the mounts, the stands and the dock see the same picture. Scars stay two
pixels in from the edge and off the lights and markings. Where they go is seeded by the
hull's key, not the run, so a hull keeps its scars from run to run; B carries the first
half of C's scars and A a few, so the ladder is one hull getting better, not four hulls.
Soft edges step in 2x2 clumps (`dith`), never single pixels, which shimmer as the ship bobs.

The junker's windows flicker at C (`HullGrade.level`'s `"flicker"`): every few seconds half
a second of stutter, then steady. They never go out for good, as Jon ruled on Nov 16 ("the
lights going black for C is weird"); a dead light bank was asked for in the brief and left
out for that reason.

Battle damage leans hardest on condition's register (HullWear draws what fights did, off hull
points), so a C in that idea can read as a hurt ship at full hull. Junker is build quality:
cheap, mismatched, cobbled together, which is what a grade is.
