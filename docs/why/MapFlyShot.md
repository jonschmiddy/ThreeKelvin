The reasoning behind `tkg/scripts/sim/MapFlyShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Map fly shot

Above `var _args: PackedStringArray`:

```text
THE MAP_FLY LINE ON THE SECTOR MAP, as the game draws it:
  godot --path . --windowed --resolution 1920x1080 -- sheet=MapFlyShot ash hints out=<dir> [seed=4242] [node=N]

A run under way (its jump made, every other hint and step seen), the ship
circling the star as it arrived, in a one-sun system with one world
(`one.png`), one with the most worlds (`many.png`), the first binary
(`binary.png`, ORBITING BOTH STARS) and, with `node=N`, system N
(`nodeN.png`): A.S.H. says "Click a
world twice and we fly there. Or fly us by hand." with her outline on the
world nearest the ship (Jon, Nov 4: "Shouldn't a world be highlighted here
and not my ship?"). Each still is the whole window and a crop round the
outline and the ship at window scale (`_crop.png`). Prints the system, the
world and the boxes. Needs a window.
```
