The reasoning behind `tkg/scripts/sim/BossDeathSheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Boss death film

Above `const PAD := 40`:

```text
THE BOSSES' OWN DEATHS, FILMED WITH THEIR SCREEN HOOKS APPLIED (Oct 13).
  godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=BossDeathSheet
      out=<dir> [styles=16,17,...] [custodian=<png>] [hellbender=<png>]
Each style alone, as the fight frames it: your ship on the left, the boss on
the right, on a dark sky. The set piece's `moment`s that are screen hooks are
played here as the screen would: `shake` moves the whole view in whole
pixels, `slowmo` slows the death's own clock (the film runs on), `flash`
lays white over the screen, and the music cues (`duck`, `stinger`) show as a
caption, since the film is silent. Out: out/<id>/f_####.png and meta.json
(every moment with the death's time and the film's, and whether the last
frame is `wreck_image` pixel for pixel).
```
