The reasoning behind `tkg/scripts/ui/ChartTorn.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Torn away

Above `static var active := false`:

```text
TORN AWAY, direction B (proto/dwarf-b): the stream. The hardest galaxies, the
two dwarfs (GalaxyGen kinds 14 and 15), are being eaten by a giant neighbour.
ONE stream of the dwarf's stars (Jon, Nov 7: "a single stream of the galaxy
being pulled, rather than two") bends from the dwarf toward the giant in a short
arc and runs into its disc: the giant feeding (Jon, Nov 8, "FRAME:C": the giant
kept in the corner, no loop, nothing coming in from elsewhere, all of it in the
opening view at zoom 0.42). The stream is a tidal tail: its root as wide as the
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

## Giant on screen

Above `const GIANT_S := Vector2(-1.02, -0.56)`:

```text
The giant, on the screen (gu at zoom 1 about the dwarf's core, the core's own
frame, `vb`): up and to the left, its middle in the opening view's upper left
corner, clear of the dwarf's body, the rings' systems and the HUD's goal line, its
disc running on behind the dwarf (drawn over the sky only). Fixed on the screen (the
dwarf turns under it: it is stripped evenly all round, so nothing is lost by it),
so it never comes over the dwarf's core.
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
