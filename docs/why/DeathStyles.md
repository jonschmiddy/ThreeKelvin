The reasoning behind `tkg/scripts/sim/DeathStyles.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Death styles sheet

Above `var _args: PackedStringArray`:

```text
THE DEATH-ANIMATION STYLES SIDE BY SIDE, for Jon to pick one (Oct 13).
  godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=DeathStyles
      out=<dir> [boss] [style=0|1|2] [ships=cutter,sprite] [frames=N]
Without `boss`: three columns (SNAP, BURN, IMPLODE), a row per ship, every
column breaking at the same moment on a dark sky. `cutter` is the drawn
Rustjaw (EnemyArt's own canvas, starfield and all); `sprite` is a kept pool
ship (art/subjects/ships), standing in for the PixelLab enemy sprites that are
replacing the drawings -- the cut must work on either. `boss` films The
Custodian's long version in the chosen `style`, ending on its body.
Every clock is stepped 1/30 s a frame, so f_####.png at 30 fps is true speed.

`each [styles=3,4,...]` films every style on its own (default all sixteen)
into out/<id>/f_####.png, the same layout every time so a page can tile
them: A-M on the Cutter and the pool ship, N-P (the creature deaths) on the
Voidwhale Calf at 70% and the Void Leviathan (tools/art_pool/megafauna);
`eachships=custodian,cutter` puts other enemies in the two ship rows.
Each folder gets meta.json: the moments the breakup fired and when (what
sounds follow), its length, and whether its last frame is `wreck_image`
pixel for pixel (`rest_image` against `wreck_image`, both ships).
```
