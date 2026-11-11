The reasoning behind `tkg/scripts/ui/jump/JumpSeam.gd`; each heading is referenced from the code by a `Why:` line.

## Seam

Jon, Nov 11: "I think the animations and sounds are perfect, I just don't like the transition
between the jump and the sector map... it's too abrupt? it almost like flashes to the sector map.
Kinda jarring."

What the seam was, filmed frame by frame (`jumpcine whole film=r1|r9 tail=2.5 from=6.5`): every
film ends on LOCAL's settled sky (mean luma 12 of 255). On the commit frame the screen is swapped
in one frame; the map fades from alpha 0 over `Router.FADE_S` (0.13 s), but its system is drawn
behind an `await` (the sky bake), so for four frames it is a bare sun on an empty frame, and on
the fifth the orbits, paths, labels, your ship, the side panel's text and the event cards all
appear at once. The side panel's quarter goes from 11 to 28 luma in 0.13 s. Different sky,
different sun, a UI that pops: that is the flash. No white frame, and no sound is cut: the hit
cue's tail (R1 1.3 s, R9 1 s, at -40 to -60 dB) already rings on under the map.

Three ideas, different in kind, behind `-- jumpseam=t1|t2|t3` (off is today's cut), each taking
the film's last frame (the content area, the HUD left alone) before the commit:

- T1 dip: the frame falls to black over 0.4 s, a 0.25 s black beat, the map rises from black
  (0.6 s), then its UI fades in (0.35 s).
- T2 dissolve: the frame is held until the map has drawn its system, then dissolves into the
  bare map (0.9 s); the UI fades in after (0.35 s).
- T3 settle: the frame dissolves into the map's sky and system only (0.7 s), the map's paths
  and beacons come in, the side panel slides in on the calm ladder's sine and the toolbar and
  key fade, and only then does your ship warp in at the edge (its own streak and dust ring,
  `warp_t` moved to that moment).

The UI is held back through the goal line too (`ui_held`, `GoalLine.shows_on`). The side
panel's star portrait is a shader that writes COLOR and so ignores a fade; it is shown at the
halfway point of the fade rather than drawn at full strength over a faint panel. Presses are
taken by the seam until the map can be seen, then pass through. Reduced motion never plays a
film, so it never gets here; the settle's slide falls back to a fade if it ever did. Nothing
here flashes, so reduce flashes changes nothing. No zoom anywhere (Jon dislikes zoom in jumps).
