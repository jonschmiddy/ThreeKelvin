The reasoning behind `tkg/scripts/sim/FightOpenFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fight open film

Above `const Probe := preload("res://scripts/sim/FightOpenProbe.gd")`:

```text
A FIGHT OPENING ON LOCAL, filmed whole with its sound, and every element's
place on every frame of it:
  godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 60
      -- sheet=FightOpenFilm entry=<engage|event|ambush|pack|end> out=<dir> [animate]
      [wrecks=N] [wreckexit=A|B|C]  (pack: N hulls lie there first; how they leave)
`engage`  the core: LOCAL with ENGAGE on the band, pressed (`_on_action`);
`event`   an Escort event up on LOCAL, Take the contract, THEY ARE FIRING;
`ambush`  a jump into a system where something is waiting: the departure,
          the commit, and the fight that meets you there;
`pack`    LOCAL at a system with its place drawn, a fight of three started
          (`block=N`: shields up as they come; `kill`: the first killed once
          the band has settled);
`end`     a fight already under way, won, lowering into LOCAL (for comparison).
`animate` turns the motion on headless (`Router.animate_in_harness`). Prints
`mark <name> <frame>` (the movie writer's picture numbers are frames drawn)
and writes `<out>/boxes.jsonl`, one `FightOpenProbe.sample` a frame with
`f` (frame drawn) and `t` (game seconds from the trigger). Every clock the
game's.
```
