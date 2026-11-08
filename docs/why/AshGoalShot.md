The reasoning behind `tkg/scripts/sim/AshGoalShot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shot modes

Above `var _args: PackedStringArray`:

```text
A.S.H. BESIDE THE GOAL LINE, as the game draws it:
  godot --path . --windowed --resolution 1920x1080 -- sheet=AshGoalShot ash hints out=<dir> [mode=...]

mode=stills (the default): a new run on LOCAL with her and the hints on
(fresh hints; `intro=1`, the default, a profile that has not heard her
introduction, `intro=0` one that has), each of her lines photographed as it
holds (`local_<n>_<kind>.png`), then the chart (`chart.png`) and the sector
map (`map.png`) with the goal and its step up.
mode=fight: a fight's first turn with her teaching line (the hand's), the
same fight later with another (after the first card), and her bark over the
heat cap (`fight_teach_first`, `fight_teach_mid`, `fight_bark`).
mode=film: LOCAL -> SECTOR -> LOCAL by the HUD's tabs, the goal and its step
up, every frame's top left (`frames/00000.png`...): run with `--fixed-fps 30`.
mode=stepfilm: on LOCAL she says the goal's step, and its line comes back
once she is done, every frame's top left, `--fixed-fps 30`.
mode=introfilm: a new run's first LOCAL as played, for `--write-movie`: her
introduction, the beat, the goal's first step, its line coming back; it
quits a second after. Run with `--write-movie <dir>/film.avi --fixed-fps 30`.
mode=settings: Settings over the run, scrolled to HINTS (`settings.png`).
mode=decks: a station with all five decks, each opened by its button the
first time: her line on it, holding, with its outline (`deck_<id>_ash.png`),
then the same with her off, the card (`deck_<id>_card.png`); prints her box
or the card's and the outline's. `pick=low`: a station under a city, the
decks it has (`deck_low_<id>_...`).
mode=cutaway: your ship opened up on LOCAL, her cutaway line holding with
the keys under her words (`cutaway.png`), then again with TURN PART on T and
FLIP PART on G (`cutaway_rebound.png`); each also as her box alone, cropped
from the window (`_box.png`), and the keys put back after.
Each still is the whole window and a 2x crop of its top left (`_tl.png`, the
first 480x270 game pixels). Prints her box, the goal's and the step's. Needs
a window.
```
