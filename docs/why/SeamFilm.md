The reasoning behind `tkg/scripts/sim/SeamFilm.gd`; each heading is referenced from the code by a `Why:` line.

## Seam film

Above `var _tree: SceneTree`:

```text
THE TWO SEAMS OF STRIPPED-DOWN UI PART 3, FILMED (Jon, Nov 9):
  godot --path . --windowed --resolution 1920x1080 --fixed-fps 30
      --write-movie <dir>/seam.avi -- sheet=SeamFilm what=decks|loot [seed=N] [rm]
`what=decks`: docked at once (no dock played), the berth settled, then the
elevator pressed deck by deck: up to the PROMENADE, down to the LABORATORY,
up to the EXCHANGE, down to the HIRING BOARD, down to the yard, each held a
little over a second after it lands. `what=loot`: LOCAL with a wreck of three
things and a pile of two; the pointer glides to the wreck and clicks it, the
view opens and is held, one part is taken by a double-click on it (the
first-run bot's way: a pushed drag does not start Godot's), DONE, then
SECTOR LOOT on the bar, held, DONE. `rm` films under reduced motion.

Every clock is the game's: the deck slide and the loot view's push-in run on
process delta, which `--fixed-fps 30` holds at a thirtieth, so the film plays
at true speed however long a frame takes to write (`GameClock`; the wall clock
ran films 12.7x too fast). Prints `mark <name> <frame>`, the AVI's frame each
step began on, for cutting stills. Encode with tools/dev/encode_video.py at
1920x1080 for the phone (the game at 2x).
```
