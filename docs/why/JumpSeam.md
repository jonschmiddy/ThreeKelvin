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
cue's tail (R1 1.3 s, R9 1 s, at -40 to -60 dB) already rings on under the map, and still does.

Three ideas were filmed from one build behind a dev switch (tk-scratch/jump-drive/seam): T1 a dip
through black, T2 a held frame dissolving into the map, T3 a settle. Jon picked T3 (Nov 11), and
the switch and the other two went.

The settle: the film's last frame (the content area; the HUD is the same on both sides and left
alone) is taken before the commit and laid over the map. It is held until the map has drawn its
system, then dissolves into the map's sky, sun and orbits (0.7 s) with the paths, beacons and
ship held back; the paths come in (0.6-1.1 s). At 1.0 s the side panel, the top row and the KEY
band slide on together, drawn whole, as the calm ladder brings them when a move lands
(`PanelSlide`s made as `ZoomLadder._panels_slide` makes them: side from the right, row from the
top, band from the bottom; `CALM_SLIDE_S` on `_calm_slide_curve`, whole pixels), and the words
(labels, scale, LOCATION) fade in after over `CALM_IN_S`. Jon asked (Nov 11) "does the bottom
panel slide in?": the first settle slid only the side panel and faded the row and the KEY band;
since F1 the ladder slides all three, so the settle does too. Then your ship warps in at the
edge (its own streak and dust ring, `warp_t` moved to that moment, 1.75 s). A map that never
draws its system within 2 s is handed back as it stands. The side panel's slide is silent here:
the ladder's `chrome_on` would land on the film's ringing tail.

The UI is held back through the goal line too (`ui_held`, `GoalLine.shows_on`). The side
panel's star portrait is a shader that writes COLOR and so ignores a fade, so it is hidden until
the panel slides, not left at full strength over a faint one. The "YOU" edge arrow is off while
the ship is held back (it pointed at the ship's last drawn place, the frame's corner). Presses
are taken by the seam until the map can be seen, and after that only on a panel still moving
(as the ladder eats them), so nothing is clickable while it moves.

Off where there is no picture: headless (`get_image` has nothing to read) and wherever
`Router.animating()` is false (reduced motion, the sim, the shot tools) take the cut, and
nothing is hidden then, because the map's UI is only touched once a seam exists. Reduced motion
never plays a film anyway. Nothing here flashes,
so reduce flashes changes nothing. No zoom (Jon dislikes zoom in jumps).
