The reasoning behind `tkg/scripts/sim/EnemyArtTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Enemy art test

Above `var _fails := 0`:

```text
THE ENEMIES' PICTURES, headless:
  godot --headless --path . -- sheet=EnemyArtTest
Jon kept PixelLab ships for every enemy (Oct 13): three per ordinary kind,
one chosen per fight; one each for the Hellbender, the Custodian, the calf
and the Leviathan. This checks:
  - EVERY KIND HAS A PICTURE: each enemy id names at least one file
    (`art/sprites/enemies/index.json`), every file loads, fits the canvas
    (`EnemyArt.W` x `H`), is hard-edged (alpha 0 or 255), and is what
    `EnemyArt` draws -- the sprite, not the coded fallback, and nothing else
    on the canvas (no stars: a breakup cuts the canvas by its alpha);
  - THE PICTURE IS THE FIGHT'S, NOT A ROLL: `Combat.look_for` gives the same
    ships for the same fight asked twice and in a second run of the same
    galaxy, different ships across systems (each three-picture kind shows all
    three somewhere), and the look survives into the wrecks the win leaves
    (in fight order) and through the save;
  - PACKS FIT: the real fight opened on every pair of kinds a fight can
    roll at their widest pictures, every picture beside the widest ship, a
    the dev flag's three: once the entrance
    has landed, every ship where its art actually IS -- inside the view, clear
    of your ship, your ship not moved -- and a lone ship in the middle of the
    enemy half.
```
