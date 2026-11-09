The reasoning behind `tkg/scripts/sim/HullDamageSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull damage stills

Above `const Film := preload("res://scripts/sim/HullDamageFilm.gd")`:

```text
THE HULL DAMAGE LOOKS SIDE BY SIDE, AS STILLS (Oct 17), for working on them
without a fight: each ship's picture taking `HullDamageFilm`'s nine hits in
each look, the clock stepped 1/30 s, photographed at four moments -- just
after the first hit, just after the fourth, a second after the sixth, and
2.6 s after the last -- as the marks and the light on the plating (no
sparks or vapour: those are drawn, not baked). Headless.
  godot --headless --path . -- sheet=HullDamageSheet out=<png>
      [ships=cutter:0,hulk:0,marauder:2] [looks=0,1,2,3,4] [scale=1|0.5] [k=2]
One PNG a ship (`<out>_<ship>.png`), one row a look, today's first. `scale=0.5` uses the half sheets, as
a pack of three draws them.
```
