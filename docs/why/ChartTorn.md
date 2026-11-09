The reasoning behind `tkg/scripts/ui/ChartTorn.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Torn away

Above `static var active := false`:

```text
TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour.
ONE stream of the dwarf's stars (Jon, Nov 7: "a single stream of the galaxy
being pulled, rather than two") runs from the dwarf into the giant: since Nov 8 the
hook (below, `#the-hook`), which replaced "FRAME:C"'s short arc into a giant kept in
the corner. The stream is a tidal tail: its root as wide as the
dwarf is drawn now ("the stream coming from the dwarf galaxy can start the same
width as the dwarf galaxy and get smaller towards the galaxy that is eating it"),
so it narrows as the dwarf is stripped, tapering to a thread where it meets the
giant (`root_w`, the shader's `tornWA`).

THE DWARF'S CLOUDS (Jon, Nov 8: "nebula in the dwarf galaxy should dissapear or
become distorted as the galaxy is eated"): the chart's named clouds over the
dwarf shear a little as it is stripped, and those the torn edge has passed are
drawn out toward the giant and fade (`cloud_tear`); by the end none is left whole.
The chart's drawing only: where a cloud stands for the game (`NebulaField`, a
system in the gas) is unchanged.

THE DWARF IS DRAWN BIG (Jon, Nov 8, "SIZE: bigger", and "I basically want the
dwarf to be drawn large, and then get smaller and smaller as it's stripped away
to nothing"): its body reaches past its outermost ring (`cover`), whether TORN
AWAY is on or not, so every system sits on it. Its core keeps its real size; the
body round it is a faint envelope (`ball_v`, read by every style's ball), its
light, clumps and stars read at the new size, never a picture scaled up.

The rings fall away from the outside in (`lost`, rings gone so far, to
`max_lost`). With each ring lost the dwarf is REDRAWN, never shrunk (Jon, Nov 8:
"it's almost like the image of the galaxy is shrinking rather than a true
redraw"): REDRAW A, STRIPPED. Its core, body, glow and stars keep their size and
place; past its edge (`edge`, at the rings' own radii, `ring_r`) they are gone,
the edge torn (ragged on the galaxy's own noise, never inside the outermost ring
still standing, drawn out toward the stream, its last band broken into clumps that
feed the stream's start). The systems on the lost rings are off the chart (`gone`,
`StarchartScreen._drop_torn`). No ring is marked (Jon: "I don't want the red ring
to be in the game").

THE END (one switch, `ending`; Jon ruled F, Nov 8): the last four rings never
fall. F (the default, the rules unchanged): rings 0-9 can fall, and the picture is
stripped to nothing as ring 9 goes; the four inner rings' systems are left where
they stand, loose stars where the dwarf was. N (kept as a switch, off the default
path): all 14 rings can fall, and the dwarf is eaten whole.

Drawn by every style's place pass (`chart_torn_core.gdshaderinc`, and PAINTED's
`chart_torn.gdshaderinc`) from these uniforms. Off unless the run sets it
(`active`), so no dwarf run changes but for its size until TORN AWAY is built.

Proto: `lost` is set by hand (`sheet=ChartLook torn=N`); the mechanic that
drives it is being designed elsewhere.
```

## The hook

Above `const HOOK_PX := 1.5`:

```text
THE HOOK (Jon, Nov 8: "THIS IS EXACTLY RIGHT!!!", the approved mockup
tk-scratch/dwarf-eaten/hook-mockup/index.html, from his sketch). It replaces direction
B's short arc into a giant cut off in the corner.

THE COMPOSITION: the giant (the eating galaxy) whole in the opening's upper left, the
dwarf down and to its right. The stream leaves the dwarf's LEFT side as a wide band,
heads left, swings down and round, then climbs up into the giant's UNDERSIDE: the
mockup's cubic bezier (root on the dwarf's left side -> HOOK_C1 on from the root ->
HOOK_C2X left of the giant at HOOK_C2Y below the core -> HOOK_IN off the giant's middle).
It narrows toward the giant (`tornW`: the root's half width less 85% along it). The
mockup's numbers are kept in its own pixels about the dwarf's core and drawn at
HOOK_PX opening px each (the mockup drew 1 px for 2.5 window px; here 1.5).

WHY NOT THE MOCKUP'S SCALE: the game's dwarf is drawn big (its body covers all 14
rings, Jon's "SIZE: bigger"), about 2.5x the mockup's against the frame, and the opening
zoom is the chart's least (ZOOM_MIN). At the mockup's own 2.5 the giant falls off the
chart's left. At 1.5 the giant, the hook and the giant's growth all fit in the chart, so
the giant and the stream match the mockup's camera and the dwarf is bigger than its.

THE OPENING (TORN AWAY on): the core OPEN_SHIFT right and down of the chart's middle
(0.25, 0.135 gu at zoom 1: 65, 35 px at the opening), where the run's first chart opens
and where FRAME GALAXY (LOCAL REGION off) goes back to (`MapChart._open_pan`). The
dwarf's systems still all fit the opening clear of the toggles and the scale. Without
it the giant's disc ran past the chart's left edge at any size that still read as the
bigger galaxy.

THE DECAY (`share` = rings lost over HOOK_LOST, 10, ending F's whole fall): at 0 lost
the stream is already 62% of the way round (`reach` = min(1, 0.62 + 1.3 share)), its
leading tip narrowing to a point over its last third; from about 3 lost it reaches all
the way in. The giant closes in (GIANT_IN mockup px) and grows (GIANT_GROW, 1.3x by 10
lost); the stream's giant end follows it. The root narrows as the mockup's dwarf does
(46 px less 3.4 a ring). The dwarf is still stripped ring by ring as before and its
clouds smear toward the stream's first bend (`cloud_tear`).

ITS MATTER DRIFTS (Jon's sketch, "stars, gas, nebulae slowly streaming"): stars (a block),
puffs of its gas (2 x 2) and pink cloud specks (2 x 1) ride lanes along it toward the
giant, each lane at its own calm pace, a block a step (`tornDrift`, the old lanes'
clock): a frame moves a lane or two, nothing flips back. Its band of light is held where
it lies; only the sprites move. Nothing clickable moves.

PAINTED's band is held at its arm ramp's step 0.5 at most (`tornOver`): at the ramp's
top steps the sky under the rim's marks rose to 136 (MARK_LUMA 110, TornTest).

PARALLAX: the giant is further off than the chart's plane, so a pan moves it `par` of
the way: 0.4 at 0 lost rising to 0.8 at 10 as it closes in. The chart (the dwarf, its
systems, YOU) pans 1:1, and so does the stream for most of its length: its root, its
lower sweep and its bottom-left turn (P0, P1, P2) are held with the dwarf, and only its
end in the giant's underside (P3) takes the giant's share. On the cubic that moves the
climb alone (weight t^3). Jon, Nov 8: he first had the points blending 1:1 to the
giant's share along the stream, saw the whole tail swing as he panned and did not like
it. `HOOK_BEND` would start the bend earlier (P2 that share of the way toward the
giant's); it is 0: drags of 140 px at 3 and 10 lost bent the climb smoothly, with no
kink and nothing detached (at 0 lost the stream stops short of the climb and pans 1:1
whole). Each moving point slides as one rigid layer in whole blocks (`slide`), as a
galaxy's depth does (chart_depth's `depthSlide`): continuous parallax crawled there.
The pan is read off the chart (`push`'s pan and zoom) against the opening's.
```

## Cloud tear

Above `const CLOUD_FLAT := 0.46341`:

```text
How far a named cloud at plane point xy (gu, the chart's `clouds`' `xy`; reach its
size) is torn, and which way it is drawn out, at this turn: [tear, way].
tear: x how far gone (0 whole, 1 gone: it fades), y how far drawn out (its length
along the way is 1 + y of its own), z how far it has slid toward the giant (gu),
w the shear of one still standing in the body. way: xy the way to the giant on
the screen in the cloud's round frame (y over the clouds' flatness), zw the same
in the galaxy's plane (RADIANT's, which marches the clouds there). All zero (whole,
as drawn today) off TORN AWAY, and for a cloud outside the dwarf.
```
