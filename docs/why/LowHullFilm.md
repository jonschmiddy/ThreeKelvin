The reasoning behind `tkg/scripts/sim/LowHullFilm.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Low hull film

Above `const VOICE_GAP_S := 0.5`:

```text
THE HULL FAILING, FILMED (`LowHull`, `HullScramble`), with sound, at true speed:
  godot --path . --resolution 1920x1080 --write-movie <dir>/film.avi --fixed-fps 30
      -- sheet=LowHullFilm scene=<local|fight|tooltip|ramp> [lowhull=subtle|medium|strong]
         [hull=0.22] [secs=8] [ash=1] out=<dir>
  local    LOCAL with the hull at `hull` of its max, the state already eased in
  fight    a fight with a pirate cutter at `hull`; two cards played
  tooltip  LOCAL at `hull`, the HUD hull's tooltip up (built the way Godot
           builds one: its TooltipPanel and TooltipLabel, under the cells)
  ramp     LOCAL at 35%, the hull stepping to 30, 20, 10 and 5% every
           `step` s (2.5), then repaired to 60%
  `ash=1`: A.S.H. says the same line (`line_of`) a second in, glitched by the
  hull's depth, her portrait slipping in step.
Each runs a pre-roll first (the screen settling, the state easing in), then
writes `marks.json` into `out`: the movie frame the film proper starts on,
the moments in it in seconds from that start, and the scramble's measure
(runs started a second, letters scrambled at once). Every clock is the game's.

  godot --headless --path . -- sheet=LowHullFilm scene=voice out=<dir>
writes `voice.wav`: her line (`line_of`) at 30, 20, 10 and 5% of the hull,
back to back with VOICE_GAP_S of silence between, each through the same
worker path she is heard through in play (`VoiceGlitch.bake_placed`), and
`voice.json`, where each glitch is.
```
