The reasoning behind `tkg/scripts/sim/BestiarySheet.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Bestiary sheet

Above `const OUT := "user://bestiary"`:

```text
Every enemy body at every damage band, as PNGs.

    godot --headless --path . -- bestiary

EnemyArt is a TextureRect but it composites CPU-side into an Image, so it
works with no renderer at all — the same trick WearSheet uses on hulls.

The point of this one is the SUBSTANCE split. A whale does not weld and a
gunship does not scar, and this is where that gets looked at rather than
argued about.
```
