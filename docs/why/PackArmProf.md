The reasoning behind `tkg/scripts/sim/PackArmProf.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pack arm profile

Above `const KINDS: Array[StringName] = [&"cutter", &"lancer", &"hulk", &"marauder", &"sentinel", &"whale"]`:

```text
WHAT A PACK'S HIT LAYERS COST TO BUILD AS ITS FIGHT OPENS (perf, Oct 27).
  godot --headless --fixed-fps 60 --path . -- sheet=PackArmProf [reps=5]
A ship's `HitLayers` (its marks, bubble and armour, `EnemySlot._arm`) are
built from its picture as drawn. A pack of three or more is drawn from half
sheets, a size the layout sets after the bind (`EncounterView._layout_pack`),
and its layers wait for that size (`EnemySlot.layers_wait`); before Oct 27
they were built at full size in the bind and again at half, the first build
thrown away. Prints first, for each kind, one `_arm` at full size and one at
half (ms, median of `reps`); then, for packs of three and four through the
real `Router.start_combat` from LOCAL:
  still     not animated (headless, reduced motion): the bind and the layout
            in the one call; `open ms` is that call, the whole opening;
  animated  `Router.animate_in_harness`, the row held while LOCAL's band
            goes (`EncounterView.hold_row`): the layout a few frames later;
for each: the enemy layers built (`builds`; one a ship is the floor), the
half-sheet ones among them, the size the kept ones were built at, and the
`_arm` time those builds cost (`arm ms`, from the kinds' costs above). A
build is counted as its `HitLayers` enters the tree (yours, which follows
your `ShipView`, is not counted). With `_arm` patched locally to add its own
time to the `Engine` meta `prof_arm_us`, `measured` prints that too.
Profiler only: nothing here fails.
```
